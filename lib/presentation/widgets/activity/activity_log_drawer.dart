import 'package:flutter/material.dart';

import 'package:letsfly_mobile/core/constants/app_colors.dart';

import 'package:letsfly_mobile/core/accessibility/gesture_controller.dart';



enum ActivityCategory {

  all,

  tableChat,

  privateMessages,

  friends,

  gameplay,

  friendRequests,

  invitations,

  gifts,

}



class ActivityItem {

  final String text;

  final ActivityCategory category;

  final DateTime timestamp;



  const ActivityItem({

    required this.text,

    required this.category,

    required this.timestamp,

  });

}



class ActivityLogDrawer extends StatefulWidget {

  final bool showChatInput;

  final List<ActivityItem> items;

  final ValueChanged<String>? onSendMessage;

  final VoidCallback onClose;



  const ActivityLogDrawer({

    super.key,

    required this.showChatInput,

    required this.items,

    this.onSendMessage,

    required this.onClose,

  });



  @override

  State<ActivityLogDrawer> createState() => _ActivityLogDrawerState();

}



class _ActivityLogDrawerState extends State<ActivityLogDrawer> {

  ActivityCategory _selectedCategory = ActivityCategory.all;

  final TextEditingController _chatController = TextEditingController();



  @override

  void dispose() {

    _chatController.dispose();

    super.dispose();

  }



  void _sendMessage() {

    final text = _chatController.text.trim();

    if (text.isNotEmpty) {

      widget.onSendMessage?.call(text);

      _chatController.clear();

    }

  }



  String _getCategoryName(ActivityCategory category) {

    switch (category) {

      case ActivityCategory.all:

        return 'الكل';

      case ActivityCategory.tableChat:

        return 'دردشة الطاولة';

      case ActivityCategory.privateMessages:

        return 'الرسائل الخاصة';

      case ActivityCategory.friends:

        return 'الأصدقاء';

      case ActivityCategory.gameplay:

        return 'أحداث اللعب';

      case ActivityCategory.friendRequests:

        return 'طلبات الصداقة';

      case ActivityCategory.invitations:
        return 'الدعوات';
      case ActivityCategory.gifts:
        return 'الهدايا';
    }

  }



  List<ActivityItem> get _filteredItems {

    if (_selectedCategory == ActivityCategory.all) {

      return widget.items;

    }

    return widget.items.where((i) => i.category == _selectedCategory).toList();

  }



  @override

  Widget build(BuildContext context) {

    return LetsFlyGestureWrapper(

      handler: LetsFlyGestureHandler(

        onSwipeRight: widget.onClose,

      ),

      child: Container(

        height: MediaQuery.of(context).size.height * 0.85,

        decoration: const BoxDecoration(

          color: AppColors.background,

          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

        ),

        child: Column(

          children: [

            // Header

            Semantics(

              header: true,

              label: 'لوحة السجل',

              child: Container(

                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                decoration: const BoxDecoration(

                  color: AppColors.surface,

                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

                ),

                child: Row(

                  children: [

                    const Icon(Icons.history, color: AppColors.primary),

                    const SizedBox(width: 8),

                    const Expanded(

                      child: Text(

                        'السجل',

                        style: TextStyle(

                          fontSize: 20,

                          fontWeight: FontWeight.bold,

                          color: AppColors.textPrimary,

                        ),

                      ),

                    ),

                    Semantics(

                      label: 'إغلاق السجل',

                      button: true,

                      child: IconButton(

                        icon: const Icon(Icons.close, color: AppColors.textPrimary),

                        tooltip: 'إغلاق السجل',

                        onPressed: widget.onClose,

                      ),

                    ),

                  ],

                ),

              ),

            ),



            // Category Filter Bar

            Container(

              height: 48,

              color: AppColors.surface,

              child: ListView(

                scrollDirection: Axis.horizontal,

                padding: const EdgeInsets.symmetric(horizontal: 8),

                children: ActivityCategory.values.map((cat) {

                  final isSelected = cat == _selectedCategory;

                  return Padding(

                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),

                    child: ChoiceChip(

                      label: Text(_getCategoryName(cat)),

                      selected: isSelected,

                      selectedColor: AppColors.primary,

                      onSelected: (val) {

                        if (val) {

                          setState(() {

                            _selectedCategory = cat;

                          });

                        }

                      },

                    ),

                  );

                }).toList(),

              ),

            ),



            // Activity Log List

            Expanded(

              child: _filteredItems.isEmpty

                  ? Center(

                      child: Text(

                        'لا توجد أحداث في قسم ',

                        style: const TextStyle(color: AppColors.textSecondary),

                      ),

                    )

                  : ListView.builder(

                      padding: const EdgeInsets.all(12),

                      reverse: true,

                      itemCount: _filteredItems.length,

                      itemBuilder: (context, index) {

                        final item = _filteredItems[_filteredItems.length - 1 - index];

                        return Padding(

                          padding: const EdgeInsets.symmetric(vertical: 4),

                          child: Container(

                            padding: const EdgeInsets.all(10),

                            decoration: BoxDecoration(

                              color: AppColors.surface,

                              borderRadius: BorderRadius.circular(8),

                            ),

                            child: Text(

                              item.text,

                              style: const TextStyle(

                                color: AppColors.textPrimary,

                                fontSize: 16,

                              ),

                            ),

                          ),

                        );

                      },

                    ),

            ),



            // Table Chat Input Box (ONLY if showChatInput == true)

            if (widget.showChatInput)

              Container(

                padding: const EdgeInsets.all(8),

                decoration: const BoxDecoration(

                  color: AppColors.surface,

                  border: Border(top: BorderSide(color: Colors.white12)),

                ),

                child: SafeArea(

                  top: false,

                  child: Row(

                    children: [

                      Expanded(

                        child: Semantics(

                          label: 'اكتب رسالة دردشة للطاولة',

                          child: TextField(

                            controller: _chatController,

                            style: const TextStyle(color: Colors.white),

                            decoration: const InputDecoration(

                              hintText: 'اكتب رسالة للطاولة...',

                              hintStyle: TextStyle(color: AppColors.textSecondary),

                              border: OutlineInputBorder(),

                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),

                            ),

                            onSubmitted: (_) => _sendMessage(),

                          ),

                        ),

                      ),

                      const SizedBox(width: 8),

                      Semantics(

                        label: 'إرسال الرسالة',

                        button: true,

                        child: IconButton(

                          icon: const Icon(Icons.send, color: AppColors.primary),

                          onPressed: _sendMessage,

                        ),

                      ),

                    ],

                  ),

                ),

              ),

          ],

        ),

      ),

    );

  }

}

