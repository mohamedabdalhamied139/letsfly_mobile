class GameSettingField {
  final String key;
  final String label;
  final String kind;
  final dynamic defaultValue;
  final int minimum;
  final int? maximum;
  final int step;
  final List<String> options;
  final String? group;
  const GameSettingField({required this.key, required this.label, this.kind='bool', this.defaultValue=false, this.minimum=1, this.maximum, this.step=1, this.options=const [], this.group});
}

class GameSettingsDefinition {
  final String game;
  final int defaultTarget;
  final Map<String,dynamic> defaults;
  final List<GameSettingField> fields;
  const GameSettingsDefinition(this.game, this.defaultTarget, this.defaults, this.fields);
}

const _unoChildren = ['skip_everyone','discard_all','wild_draw_six_ten','wild_reverse_draw_four','color_roulette'];

final Map<String,GameSettingsDefinition> gameSettingsRegistry = {
  'UNO': GameSettingsDefinition('UNO',500,{
    'responses':false,'straights':false,'interceptions':false,'super_interceptions':false,'bluff':false,'skip_after_draw':false,'zero_seven':false,'buzzer':false,'advanced_responses':false,'draw_until_playable':false,'eliminate_too_many':false,'no_mercy':false,'skip_everyone':false,'discard_all':false,'wild_draw_six_ten':false,'wild_reverse_draw_four':false,'color_roulette':false,'uno_flip':false,
  }, [
    const GameSettingField(key:'responses',label:'الردود (+2 و+4)'), const GameSettingField(key:'straights',label:'المتتاليات'), const GameSettingField(key:'interceptions',label:'الاعتراضات'), const GameSettingField(key:'super_interceptions',label:'الاعتراضات الفائقة'), const GameSettingField(key:'bluff',label:'الخداع'), const GameSettingField(key:'skip_after_draw',label:'التخطي بعد السحب'), const GameSettingField(key:'zero_seven',label:'قاعدة 0/7'), const GameSettingField(key:'buzzer',label:'الجرس'), const GameSettingField(key:'advanced_responses',label:'الردود المتقدمة'), const GameSettingField(key:'draw_until_playable',label:'السحب حتى كارت قابل للعب'), const GameSettingField(key:'eliminate_too_many',label:'إقصاء من يسحب كثيرًا'), const GameSettingField(key:'no_mercy',label:'حزمة UNO No Mercy'), const GameSettingField(key:'skip_everyone',label:'تخطي الجميع'), const GameSettingField(key:'discard_all',label:'إسقاط كل كروت اللون'), const GameSettingField(key:'wild_draw_six_ten',label:'Wild Draw 6/10'), const GameSettingField(key:'wild_reverse_draw_four',label:'Wild Reverse Draw 4'), const GameSettingField(key:'color_roulette',label:'عجلة الألوان'), const GameSettingField(key:'uno_flip',label:'UNO Flip'),
  ]),
  'THIEF_HUNT': GameSettingsDefinition('THIEF_HUNT',5,{'rounds':5,'allow_human_thief':false,'elimination_mode':false},[const GameSettingField(key:'rounds',label:'عدد الجولات',kind:'number',defaultValue:5,minimum:1,step:1),const GameSettingField(key:'allow_human_thief',label:'السماح باللص البشري'),const GameSettingField(key:'elimination_mode',label:'نظام الخروج المباشر')]),
  'FARKLE': GameSettingsDefinition('FARKLE',1500,{'min_bank':30,'first_bank_min':50},[const GameSettingField(key:'min_bank',label:'الحد الأدنى للتثبيت',kind:'number',defaultValue:30,minimum:30,step:10),const GameSettingField(key:'first_bank_min',label:'الحد الأدنى لأول تثبيت',kind:'number',defaultValue:50,minimum:50,step:10)]),
  'DOMINO': GameSettingsDefinition('DOMINO',100,{'mode':'draw','hand_size':7},[const GameSettingField(key:'mode',label:'نظام اللعب',kind:'choice',defaultValue:'draw',options:['draw','block']),const GameSettingField(key:'hand_size',label:'حجم اليد',kind:'number',defaultValue:7,minimum:1,maximum:7)]),
  'AMERICAN_DOMINO': GameSettingsDefinition('AMERICAN_DOMINO',150,{'hand_size':7,'scoring_mode':'standard'},[const GameSettingField(key:'scoring_mode',label:'نظام النقاط',kind:'choice',defaultValue:'standard',options:['standard','unit']),const GameSettingField(key:'hand_size',label:'حجم اليد',kind:'number',defaultValue:7,minimum:1,maximum:7)]),
  'SNAKES_LADDERS': GameSettingsDefinition('SNAKES_LADDERS',100,{'knockout':false,'mystery_tiles':false},[const GameSettingField(key:'knockout',label:'إسقاط المنافسين عند الوقوف على نفس المربع'),const GameSettingField(key:'mystery_tiles',label:'صناديق الحظ والمفاجآت')]),
  'SCOPA': GameSettingsDefinition('SCOPA',11,{'scopa_mode':'classic','classic':true,'escoba_15':false,'asso_piglia_tutto':false,'scopone':false,'inverted':false},[const GameSettingField(key:'scopa_mode',label:'وضع إسكوبا',kind:'choice',defaultValue:'classic',options:['classic','escoba_15','asso_piglia_tutto','scopone']),const GameSettingField(key:'inverted',label:'الوضع المعكوس')]),
  'TENNIS': GameSettingsDefinition('TENNIS',1,{'bot_difficulty':'NORMAL'},[const GameSettingField(key:'bot_difficulty',label:'صعوبة البوت',kind:'choice',defaultValue:'NORMAL',options:['EASY','NORMAL','HARD','EXPERT']),const GameSettingField(key:'sets',label:'عدد المجموعات للفوز',kind:'number',defaultValue:1,minimum:1,maximum:5)]),
  'NINETY_NINE': GameSettingsDefinition('NINETY_NINE',11,{'starting_tokens':11},[const GameSettingField(key:'starting_tokens',label:'الرصيد الابتدائي',kind:'number',defaultValue:11,minimum:1,maximum:99)]),
};

Map<String,dynamic> normalizeGameRules(String game, Map<String,dynamic> values) {
  final g=game.toUpperCase();
  final d=gameSettingsRegistry[g];
  final out=<String,dynamic>{...(d?.defaults ?? const {}), ...values};
  if(g=='UNO') {
    if(out['uno_flip']==true || out['no_mercy']!=true) for(final k in _unoChildren) out[k]=false;
    if(out['uno_flip']==true) out['no_mercy']=false;
  }
  if(g=='DOMINO') out['mode']=out['mode']=='block'?'block':'draw';
  if(g=='AMERICAN_DOMINO') out['scoring_mode']=out['scoring_mode']=='unit'?'unit':'standard';
  if(g=='SCOPA') {
    final mode='${out['scopa_mode'] ?? 'classic'}';
    out['scopa_mode']=['classic','escoba_15','asso_piglia_tutto','scopone'].contains(mode)?mode:'classic';
    out['classic']=out['scopa_mode']=='classic'; out['escoba_15']=out['scopa_mode']=='escoba_15'; out['asso_piglia_tutto']=out['scopa_mode']=='asso_piglia_tutto'; out['scopone']=out['scopa_mode']=='scopone';
  }
  if(g=='TENNIS') out['bot_difficulty']=['EASY','NORMAL','HARD','EXPERT'].contains(out['bot_difficulty'])?out['bot_difficulty']:'NORMAL';
  if(g=='NINETY_NINE') out['starting_tokens']=int.tryParse('${out['starting_tokens']}') ?? 11;
  return out;
}

(int target, Map<String,dynamic> rules) mapGameSettings(String game, int target, Map<String,dynamic> values) {
  final g=game.toUpperCase(); final r=normalizeGameRules(g,values);
  switch(g) {
    case 'NINETY_NINE': return (target, {'starting_tokens':target});
    case 'SNAKES_LADDERS': return (100, {'knockout':r['knockout']==true,'mystery_tiles':r['mystery_tiles']==true});
    case 'SCOPA': return (target, r);
    case 'DOMINO': return (target, {'mode':r['mode'],'hand_size':7});
    case 'AMERICAN_DOMINO':
      var t=target; final mode=r['scoring_mode']; if(mode=='unit' && t==150)t=30; return (t, {'hand_size':7,'scoring_mode':mode});
    case 'THIEF_HUNT': final rounds=int.tryParse('${r['rounds']}')??5; return (rounds, {'rounds':rounds,'allow_human_thief':r['allow_human_thief']==true,'elimination_mode':r['elimination_mode']==true});
    case 'FARKLE': return (target, {'min_bank':int.tryParse('${r['min_bank']}')??30,'first_bank_min':int.tryParse('${r['first_bank_min']}')??50});
    case 'TENNIS': return (target, {'bot_difficulty':r['bot_difficulty']});
    case 'UNO': return (target,r);
    default: return (target,r);
  }
}
