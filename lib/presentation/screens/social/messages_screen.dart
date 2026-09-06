import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/social_repository.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override State<MessagesScreen> createState()=>_MessagesScreenState();
}
class _MessagesScreenState extends State<MessagesScreen>{
  late Future<Map<String,dynamic>> _future;
  @override void initState(){super.initState();_future=context.read<SocialRepository>().messages();}
  void _reload()=>setState(()=>_future=context.read<SocialRepository>().messages());
  Future<void> _send() async {
    final uid=TextEditingController(); final text=TextEditingController();
    try{await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('إرسال رسالة'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:uid,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'رقم المستخدم')),TextField(controller:text,maxLines:4,decoration:const InputDecoration(labelText:'الرسالة'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),ElevatedButton(onPressed:()async{final id=int.tryParse(uid.text.trim());final msg=text.text.trim();if(id==null||msg.isEmpty)return;try{await context.read<SocialRepository>().message(id,msg);if(ctx.mounted)Navigator.pop(ctx);_reload();}catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text('فشل إرسال الرسالة: $e')));}},child:const Text('إرسال'))]));}finally{uid.dispose();text.dispose();}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('الرسائل الخاصة'),actions:[IconButton(onPressed:_send,icon:const Icon(Icons.edit),tooltip:'رسالة جديدة'),IconButton(onPressed:_reload,icon:const Icon(Icons.refresh),tooltip:'تحديث')]),body:FutureBuilder<Map<String,dynamic>>(future:_future,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text('تعذر تحميل الرسائل: ${s.error}'));final rows=s.data?['messages'] as List? ?? const [];if(rows.isEmpty)return const Center(child:Text('لا توجد رسائل.'));return ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=Map<String,dynamic>.from(rows[i] as Map);return Card(child:ListTile(title:Text('${r['sender']??''} → ${r['recipient']??''}'),subtitle:Text('${r['message']??''}\n${r['created_at']??''}')));});}));
}
