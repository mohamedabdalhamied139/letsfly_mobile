"""Adversarial challenge test suite for Milestone 1 Dynamic Localization & Pattern Resolver.

Tests the exact behavior of Dart's TranslationManager and PatternResolver against
the desktop reference client (client/localization.py).
"""
import json
import os
import re
import sys
from pathlib import Path

# Set up paths
PROJECT_ROOT = Path(__file__).resolve().parent.parent
REF_CLIENT_PATH = Path(r"C:\Users\midoa\Downloads\Compressed\LetsFly_TableVoice_Fixed_NoTableText_20260902_Final")

if str(REF_CLIENT_PATH) not in sys.path:
    sys.path.insert(0, str(REF_CLIENT_PATH))

from client.localization import TranslationManager as PyTranslationManager

# Load catalogs and patterns
loc_dir = PROJECT_ROOT / "assets" / "locales"
with open(loc_dir / "ar.json", "r", encoding="utf-8") as f:
    ar_cat = json.load(f)
with open(loc_dir / "en.json", "r", encoding="utf-8") as f:
    en_cat = json.load(f)
with open(loc_dir / "patterns.json", "r", encoding="utf-8") as f:
    raw_patterns = json.load(f)

# Build exact Dart reverse map (from translation_manager.dart lines 91-106)
en_to_ar_reverse = {}
for ar_key, en_val in en_cat.items():
    if not ar_key or not en_val:
        continue
    if en_val not in en_to_ar_reverse:
        en_to_ar_reverse[en_val] = ar_key
    else:
        prev = en_to_ar_reverse[en_val]
        if (prev.endswith(".") or prev.endswith("!")) and not (ar_key.endswith(".") or ar_key.endswith("!")):
            en_to_ar_reverse[en_val] = ar_key

# Calculate Dart priorities (from pattern_resolver.dart lines 84-91)
def dart_calculate_priority(pattern_str):
    lit = re.sub(r"\([^\)]+\)", "", pattern_str)
    lit = re.sub(r"\\[a-zA-Z]", "", lit)
    lit = re.sub(r"[\^\$\+\*\?\[\]]", "", lit)
    literal_count = len(lit.strip())
    group_matches = len(re.findall(r"\((?!\?)", pattern_str))
    return (literal_count * 100) - group_matches

# Compile Dart patterns (from pattern_resolver.dart lines 37-79)
compiled_dart_patterns = []
for item in raw_patterns:
    pat_str = item.get("pattern", "")
    template = item.get("template", "")
    raw_roles = item.get("roles", [])
    if not pat_str or not template:
        continue
    roles_map = {}
    if isinstance(raw_roles, list):
        for i, r in enumerate(raw_roles):
            roles_map[i] = str(r) if r else "text"
    elif isinstance(raw_roles, dict):
        for k, v in raw_roles.items():
            try:
                roles_map[int(k)] = str(v) if v else "text"
            except ValueError:
                pass
    pri = dart_calculate_priority(pat_str)
    try:
        reg = re.compile(pat_str, re.UNICODE)
        compiled_dart_patterns.append((reg, template, roles_map, pri))
    except Exception:
        pass

compiled_dart_patterns.sort(key=lambda x: x[3], reverse=True)

# Dart PatternResolver and TranslationManager exact logic
class DartImplementation:
    def __init__(self):
        self.locale = "ar"

    def set_language(self, lang):
        if lang in ("ar", "en"):
            self.locale = lang

    def translate(self, key, args=None):
        if not key:
            return key
        translated = self._tr_base(key)
        if not args:
            return translated
        res = translated
        for k, v in args.items():
            res = res.replace("{" + str(k) + "}", str(v) if v is not None else "")
        return res

    def resolve_dynamic_pattern(self, server_message):
        if not server_message:
            return server_message
        lang = self.locale
        # translation_manager.dart lines 156-164:
        if lang == "ar":
            if server_message in ar_cat:
                return ar_cat[server_message]
            if server_message in en_to_ar_reverse:
                return en_to_ar_reverse[server_message]
            return server_message
        return self._tr_base(server_message)

    def _resolve_role(self, val, role, active_lang):
        # pattern_resolver.dart lines 177-201
        if role == "pts":
            return "points" if val.startswith("\u0646") else "units"
        elif role == "score_list":
            return re.sub(r"(?<!\w)نقاط(?!\w)", "points", val).replace("، ", ", ")
        elif role == "set_list":
            return val.replace("، ", ", ")
        elif role in {
            "game", "title", "rules", "color", "combo", "tile", "side",
            "card", "card_list", "status", "sub"
        }:
            translated = self.translate(val)
            if role == "sub" and active_lang == "en":
                translated = re.sub(r"(?<!\w)النتائج:(?!\w)", "Scores:", translated)
                translated = re.sub(r"(?<!\w)المجموعات:(?!\w)", "Groups:", translated)
                translated = re.sub(r"(?<!\w)الدور التالي:(?!\w)", "Next turn:", translated)
                translated = re.sub(r"(?<!\w)نقاط(?=\.|،|,|$)", "points", translated)
                translated = translated.replace("، ", ", ")
            return translated
        else:
            return val

    def _pattern_resolve(self, raw_message, active_lang):
        # pattern_resolver.dart lines 96-174
        if not raw_message:
            return raw_message
        s = raw_message
        leading = s[:len(s) - len(s.lstrip())]
        trailing = s[len(s.rstrip()):]
        stripped = s.strip()

        # 1. Regex pattern matching
        for reg, template, roles_map, pri in compiled_dart_patterns:
            m = reg.match(stripped)
            if not m and stripped.endswith("."):
                m = reg.match(stripped[:-1].rstrip())
            if m:
                translated_args = []
                for i in range(len(m.groups())):
                    val = m.group(i + 1) or ""
                    role = roles_map.get(i, "text")
                    translated_args.append(self._resolve_role(val, role, active_lang))

                def repl(match):
                    idx = int(match.group(1))
                    if 0 <= idx < len(translated_args):
                        return translated_args[idx]
                    return match.group(0)

                out = re.sub(r"\{(\d+)\}", repl, template)
                return f"{leading}{out}{trailing}"

        # 2. Multi-sentence splitting
        if any(sep in stripped for sep in (". ", "! ", "؟ ", "? ")):
            parts = [p for p in re.split(r"(?<=[.!?؟])\s+", stripped) if p]
            changed = False
            translated_parts = []
            for p in parts:
                p_clean = p.strip()
                t = self.translate(p_clean)
                if t != p_clean:
                    changed = True
                    translated_parts.append(t)
                else:
                    p_test = p_clean + "." if not p_clean.endswith((".", "!", "؟", "?")) else p_clean
                    t2 = self.translate(p_test)
                    if t2 != p_test:
                        changed = True
                        translated_parts.append(t2)
                    else:
                        translated_parts.append(p)
            if changed:
                return f"{leading}{' '.join(translated_parts)}{trailing}"

        # 3. Fallback Arabic comma lists
        if "، " in stripped:
            parts = stripped.split("، ")
            trans_parts = [self.translate(p.strip()) for p in parts]
            # Dart line 168: if (transParts.any((p) => p != parts[transParts.indexOf(p)].trim()))
            if any(p != parts[trans_parts.index(p)].strip() for p in trans_parts):
                return f"{leading}{', '.join(trans_parts)}{trailing}"

        return s

    def _tr_base(self, s):
        # translation_manager.dart lines 170-285
        active = self.locale

        if active == "ar":
            if s in ar_cat:
                return ar_cat[s]
            if s in en_to_ar_reverse:
                return en_to_ar_reverse[s]

            # Comma-separated list splitting (lines 179-187)
            for sep in ("، ", ", ", " و ", " و", " and "):
                if sep in s:
                    parts = s.split(sep)
                    trans_parts = [ar_cat.get(p, en_to_ar_reverse.get(p, p)) for p in parts]
                    # Dart line 183: if (transParts.any((p) => p != parts[transParts.indexOf(p)]))
                    if any(p != parts[trans_parts.index(p)] for p in trans_parts):
                        return sep.join(trans_parts)

            # Strip trailing punctuation for reverse lookup (lines 190-201)
            stripped = s.strip()
            for punct in ("...", ".", "!", "?", ":", ","):
                if stripped.endswith(punct):
                    core = stripped[:-len(punct)].rstrip()
                    if core in en_to_ar_reverse:
                        trans_core = en_to_ar_reverse[core]
                        ar_punct = "؟" if punct == "?" else punct
                        leading = s[:len(s) - len(s.lstrip())]
                        return f"{leading}{trans_core}{ar_punct}"
            return s

        # English mode
        # 1. Exact catalog match
        if s in en_cat:
            return en_cat[s]

        stripped = s.strip()
        if stripped in en_cat:
            leading = s[:len(s) - len(s.lstrip())]
            trailing = s[len(s.rstrip()):]
            return f"{leading}{en_cat[stripped]}{trailing}"

        # Trailing punctuation handling
        for punct in ("...", ".", "!", "؟", "?", ":", "،", ","):
            if stripped.endswith(punct):
                core = stripped[:-len(punct)].rstrip()
                if core in en_cat:
                    trans_core = en_cat[core]
                    leading = s[:len(s) - len(s.lstrip())]
                    trailing_punct = "?" if punct == "؟" else punct
                    return f"{leading}{trans_core}{trailing_punct}"

        # Period fallback
        if f"{stripped}." in en_cat:
            trans = en_cat[f"{stripped}."]
            if trans.endswith("."):
                trans = trans[:-1]
            leading = s[:len(s) - len(s.lstrip())]
            trailing = s[len(s.rstrip()):]
            return f"{leading}{trans}{trailing}"

        # List translation (lines 240-251):
        for sep in ("، ", ", ", " و ", " و", " and "):
            if sep in stripped:
                parts = stripped.split(sep)
                trans_parts = [en_cat.get(p, p) for p in parts]
                # Dart line 244: if (transParts.any((p) => p != parts[transParts.indexOf(p)]))
                if any(p != parts[trans_parts.index(p)] for p in trans_parts):
                    leading = s[:len(s) - len(s.lstrip())]
                    trailing = s[len(s.rstrip()):]
                    join_sep = " and " if sep in (" و ", " و") else sep
                    return f"{leading}{join_sep.join(trans_parts)}{trailing}"

        # Compound Arabic-comma clauses (lines 254-264):
        if "، " in stripped and not re.search(r"[.!?؟]\s", stripped):
            parts = [p.strip() for p in stripped.split("، ") if p.strip()]
            if len(parts) > 1:
                trans_parts = [self._tr_base(p) for p in parts]
                # Dart line 258: if (transParts.any((tp) => tp != parts[transParts.indexOf(tp)]))
                if any(tp != parts[trans_parts.index(tp)] for tp in trans_parts):
                    leading = s[:len(s) - len(s.lstrip())]
                    trailing = s[len(s.rstrip()):]
                    return f"{leading}{', '.join(trans_parts)}{trailing}"

        # Dynamic pattern resolver
        resolved = self._pattern_resolve(s, active)
        if resolved != s:
            return resolved

        # Known compound phrases fallback (lines 275-283)
        if s.startswith("\u0625\u0639\u062f\u0627\u062f\u0627\u062a ") and not s.startswith("\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u063a\u064a\u0631"):
            remainder = s[len("\u0625\u0639\u062f\u0627\u062f\u0627\u062a "):]
            return f"{self._tr_base(remainder)} Settings"
        if s.startswith("\u0625\u062c\u0631\u0627\u0621\u0627\u062a "):
            remainder = s[len("\u0625\u062c\u0631\u0627\u0621\u0627\u062a "):]
            return f"{self._tr_base(remainder)} Actions"

        return s

# Run the battery of adversarial tests!
def run_adversarial_suite():
    sys.stdout.reconfigure(encoding="utf-8")
    py_tm = PyTranslationManager()
    dart_tm = DartImplementation()

    # Define test categories
    test_cases = [
        # --- 1. Complex UNO Patterns ---
        ("UNO Basic", "en", "أحمر 7"),
        ("UNO Zero", "en", "أصفر 0"),
        ("UNO Draw 2", "en", "أزرق سحب 2"),
        ("UNO Skip", "en", "أخضر تخطي"),
        ("UNO Reverse", "en", "أحمر عكس الاتجاه"),
        ("UNO Wild Draw 4", "en", "تبديل اللون وسحب 4"),
        ("UNO Wild", "en", "تبديل اللون"),
        ("UNO Draw 5", "en", "بنفسجي سحب 5"),
        ("UNO Bell", "en", "تركوازي جرس"),
        ("UNO Drop All", "en", "وردي إسقاط الكل"),

        # --- 2. Multi-player names with digits & special characters ---
        ("Player Digits", "en", "Player123 لعب أحمر 7"),
        ("Player Special Char", "en", "[VIP]Zaid_99 لعب أزرق سحب 2"),
        ("Player Underscore", "en", "user_name_007 لعب أخضر تخطي"),
        ("Player Mixed", "en", "bot#4 (صعب) لعب أصفر 0"),
        ("Presence Digits", "en", "gamer_99 (متصل)"),

        # --- 3. Arabic Diacritics (Tashkeel) ---
        ("Diacritics Player", "en", "مُحَمَّد لعب أحمر 7"),
        ("Diacritics Player 2", "en", "أَحْمَدُ: 100 نقاط"),

        # --- 4. Edge Cases: Arabic-comma clauses & Multi-event strings ---
        ("Comma Error Pattern", "en", "بدأت اللعبة، لكن تعذر تحميل الكروت: خطأ في الاتصال"),
        ("Comma Error Memory", "en", "بدأت اللعبة، لكن فشل تحميل البطاقات: خطأ في الذاكرة"),
        ("Comma Cards Captured", "en", "التقط 3 بطاقات، والمتبقي في البنك 5 بطاقة."),
        ("Comma Multi Player", "en", "أحمد: لعب 10، فزت 5، خسرت 5"),
        ("Comma List Known + Unknown", "en", "أحمر و لاعب1"),
        ("Comma List Two Players", "en", "أحمد و فاطمة"),
        ("Comma List Colors", "en", "أحمر، أصفر، أزرق"),

        # --- 5. Nested formatting & Sub roles ---
        ("End of Round Nested", "en", "نهاية الجولة 1: فاز أحمد. نقاط الجولة (50). النتيجة الكلية: 150، الهدف 500."),
        ("Score Points", "en", "Sarah: 250 نقاط"),
        ("Unit Points", "en", "فاز بـ 3 نقاط"),

        # --- 6. Known Compound Phrases ---
        ("Settings Prefix", "en", "إعدادات الصوت"),
        ("Actions Prefix", "en", "إجراءات الغرفة"),
        ("Guide Prefix (شرح)", "en", "شرح أونو"),
        ("Shortcuts Prefix (اختصارات)", "en", "اختصارات أونو"),

        # --- 7. Reverse Mapping & Arabic Mode Trailing Punctuation ---
        ("Reverse Question", "ar", "Are you sure?"),
        ("Reverse Period", "ar", "Main Menu."),
        ("Reverse Exclamation", "ar", "Game over!"),
        ("Reverse Dynamic Pattern Direct", "ar", "Are you sure?"),
        ("Reverse Dynamic Pattern Period", "ar", "Main Menu."),

        # --- 8. Fallback for unknown strings ---
        ("Fallback Unknown Arabic", "en", "هذه رسالة فريدة عشوائية بالكامل 98765"),
        ("Fallback Unknown English", "en", "This is an uncataloged English server broadcast"),
        ("Fallback Unknown Arabic in AR", "ar", "هذه رسالة فريدة عشوائية بالكامل 98765"),
        ("Fallback Unknown English in AR", "ar", "This is an uncataloged English server broadcast"),

        # --- 9. Punctuation Handling ---
        ("Trailing Ellipsis", "en", "جارٍ التحميل..."),
        ("Trailing Colon", "en", "النتيجة:"),
        ("Arabic Question Mark", "en", "هل ترغب بالانسحاب؟"),
    ]

    print("======================================================================")
    print("ADVERSARIAL VERIFICATION SUITE: Dart Implementation vs Python Desktop")
    print("======================================================================\n")

    failures = []
    passes = 0

    for category, lang, input_str in test_cases:
        py_tm.set_language(lang)
        dart_tm.set_language(lang)

        # Compare both translate and resolve_dynamic_pattern
        py_out = py_tm.tr(input_str)
        dart_out = dart_tm.resolve_dynamic_pattern(input_str)

        match = (py_out == dart_out)
        if match:
            passes += 1
            print(f"[PASS] [{category}] ({lang}) '{input_str}' -> '{dart_out}'")
        else:
            failures.append({
                "category": category,
                "lang": lang,
                "input": input_str,
                "py_out": py_out,
                "dart_out": dart_out,
            })
            print(f"[FAIL] [{category}] ({lang}) '{input_str}'")
            print(f"       Expected (Py):   '{py_out}'")
            print(f"       Actual (Dart):   '{dart_out}'")

    print("\n----------------------------------------------------------------------")
    print(f"Results: {passes} PASSED, {len(failures)} FAILED out of {len(test_cases)} tests.")
    print("----------------------------------------------------------------------\n")

    return failures

if __name__ == "__main__":
    fails = run_adversarial_suite()
    if fails:
        print("FAILED TEST DETAILS:")
        for f in fails:
            print(f"- Category: {f['category']}")
            print(f"  Input: {f['input']}")
            print(f"  Expected: {f['py_out']}")
            print(f"  Actual:   {f['dart_out']}\n")
        sys.exit(1)
    else:
        print("ALL ADVERSARIAL TESTS PASSED!")
        sys.exit(0)
