import 'package:flutter/material.dart';





/// Callback used by the game accessibility gesture layer.


typedef GestureCallback = void Function();





/// Actions exposed to Android accessibility services.


///


/// The raw pointer listener is intentionally kept as a secondary path for


/// devices/configurations where Flutter receives the touch stream. TalkBack


/// normally consumes its own gestures before Flutter receives those events,


/// so TalkBack support is provided through the Semantics scroll actions below.


class LetsFlyGestureHandler {


  final GestureCallback? onSwipeLeft;


  final GestureCallback? onSwipeRight;


  final GestureCallback? onSwipeUp;


  final GestureCallback? onSwipeDown;


  final GestureCallback? onDoubleTap;


  final GestureCallback? onLongPress;





  const LetsFlyGestureHandler({


    this.onSwipeLeft,


    this.onSwipeRight,


    this.onSwipeUp,


    this.onSwipeDown,


    this.onDoubleTap,


    this.onLongPress,


  });


}





/// Accessibility-aware gesture wrapper used by game screens.


///


/// Important architectural rule:


/// - Never expose game controls through [customSemanticsActions].


/// - TalkBack directional actions are represented by the standard Semantics


///   scroll callbacks.


/// - Scrollable game content must use `excludeFromSemantics: true` on its


///   ListView/ScrollView so its own ACTION_SCROLL node cannot steal the action.


///


/// The child remains a normal ListView and its individual items remain in the


/// semantics tree, so one-finger TalkBack exploration/navigation is preserved.


class LetsFlyGestureWrapper extends StatefulWidget {


  final Widget child;


  final LetsFlyGestureHandler handler;


  final String? semanticLabel;


  final String? semanticHint;





  const LetsFlyGestureWrapper({


    super.key,


    required this.child,


    required this.handler,


    this.semanticLabel,


    this.semanticHint,


  });





  @override


  State<LetsFlyGestureWrapper> createState() => _LetsFlyGestureWrapperState();


}





class _LetsFlyGestureWrapperState extends State<LetsFlyGestureWrapper> {


  final Map<int, Offset> _starts = <int, Offset>{};


  final Map<int, Offset> _current = <int, Offset>{};


  bool _triggered = false;





  static const double _threshold = 48.0;





  void _down(PointerDownEvent event) {


    _starts[event.pointer] = event.position;


    _current[event.pointer] = event.position;


    if (_starts.length >= 2) {


      _triggered = false;


    }


  }





  void _move(PointerMoveEvent e) {


    if (_triggered || !_starts.containsKey(e.pointer)) return;
    // Gameplay direction swipes require at least two active fingers.
    if (_starts.length < 2) return;


    _current[e.pointer] = e.position;





    // Calculate average movement of all active pointers


    double avgDx = 0.0;


    double avgDy = 0.0;


    for (int id in _starts.keys) {


      final s = _starts[id]!;


      final c = _current[id] ?? s;


      avgDx += (c.dx - s.dx);


      avgDy += (c.dy - s.dy);


    }


    avgDx /= _starts.length;


    avgDy /= _starts.length;





    bool horizontal = avgDx.abs() >= avgDy.abs();


    bool vertical = avgDy.abs() > avgDx.abs();





    if (horizontal && avgDx >= _threshold) {


      _triggered = true;


      widget.handler.onSwipeRight?.call();


    } else if (horizontal && avgDx <= -_threshold) {


      _triggered = true;


      widget.handler.onSwipeLeft?.call();


    } else if (vertical && avgDy >= _threshold) {


      _triggered = true;


      widget.handler.onSwipeDown?.call();


    } else if (vertical && avgDy <= -_threshold) {


      _triggered = true;


      widget.handler.onSwipeUp?.call();


    }


  }





  void _up(PointerUpEvent event) {


    _starts.remove(event.pointer);


    _current.remove(event.pointer);


    if (_starts.isEmpty) {


      _triggered = false;


    }


  }





  void _cancel(PointerCancelEvent event) {


    _starts.clear();


    _current.clear();


    _triggered = false;


  }





  double _accumulatedScroll = 0.0;


  bool _scrollTriggered = false;





  bool _handleScroll(ScrollNotification notification) {


    final isAccessible = MediaQuery.of(context).accessibleNavigation;


    if (!isAccessible) return false;





    if (notification is ScrollStartNotification) {


      _accumulatedScroll = 0.0;


      _scrollTriggered = false;


    } else if (notification is OverscrollNotification && !_scrollTriggered) {


      _accumulatedScroll += notification.overscroll;


    } else if (notification is ScrollUpdateNotification && !_scrollTriggered) {


      if (notification.scrollDelta != null) {


        _accumulatedScroll += notification.scrollDelta!;


      }


    } else if (notification is ScrollEndNotification) {


      _accumulatedScroll = 0.0;


      _scrollTriggered = false;


    }





    if (!_scrollTriggered) {


      if (_accumulatedScroll > 30) {


        _scrollTriggered = true;


        widget.handler.onSwipeUp?.call();


      } else if (_accumulatedScroll < -30) {


        _scrollTriggered = true;


        widget.handler.onSwipeDown?.call();


      }


    }





    return false;


  }





  @override


  Widget build(BuildContext context) {


    return NotificationListener<ScrollNotification>(


      onNotification: _handleScroll,


      child: Listener(


        behavior: HitTestBehavior.opaque,


        onPointerDown: _down,


        onPointerMove: _move,


        onPointerUp: _up,


        onPointerCancel: _cancel,


        child: GestureDetector(


          behavior: HitTestBehavior.opaque,


          onDoubleTap: widget.handler.onDoubleTap,


          onLongPress: widget.handler.onLongPress,


          child: Semantics(


            container: true,


            label: widget.semanticLabel,


            hint: widget.semanticHint,


            onScrollLeft: widget.handler.onSwipeLeft,


            onScrollRight: widget.handler.onSwipeRight,


            onScrollUp: widget.handler.onSwipeUp,


            onScrollDown: widget.handler.onSwipeDown,


            child: widget.child,


          ),


        ),


      ),


    );


  }


}


