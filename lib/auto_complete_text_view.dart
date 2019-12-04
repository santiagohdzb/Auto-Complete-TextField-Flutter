library auto_complete_text_view;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

typedef void OnTapCallback(String value);

class AutoCompleteTextView extends StatefulWidget
    with AutoCompleteTextInterface {
  final double maxHeight;
  final TextEditingController controller;

  //AutoCompleteTextField properties
  final tfCursorColor;
  final tfCursorWidth;
  final tfStyle;
  final tfTextDecoration;
  final tfTextAlign;
  final tfEnabled;
  //Suggestiondrop Down properties
  final suggestionStyle;
  final suggestionTextAlign;
  final onTapCallback;
  final Function getSuggestionsMethod;
  final Function focusGained;
  final Function focusLost;
  final int suggestionsApiFetchDelay;
  final Function onValueChanged;
  final Function onSubmitted;
  final TextInputAction tfInputAction;
  final FocusNode focusNode;
  
  AutoCompleteTextView(
      {@required this.controller,
      @required this.focusNode,
      this.onTapCallback,
      this.onSubmitted,
      this.maxHeight = 200,
      this.tfCursorColor = Colors.white,
      this.tfCursorWidth = 2.0,
      this.tfStyle = const TextStyle(color: Colors.black),
      this.tfTextDecoration = const InputDecoration(),
      this.tfTextAlign = TextAlign.left,
      this.tfEnabled = true,
      this.tfInputAction = TextInputAction.unspecified,
      this.suggestionStyle = const TextStyle(color: Colors.black),
      this.suggestionTextAlign = TextAlign.left,
      @required this.getSuggestionsMethod,
      this.focusGained,
      this.suggestionsApiFetchDelay = 0,
      this.focusLost,
      this.onValueChanged});
  @override
  _AutoCompleteTextViewState createState() => _AutoCompleteTextViewState();

  //This funciton is called when a user clicks on a suggestion
  @override
  void onTappedSuggestion(String suggestion) {
    onTapCallback(suggestion);
  }
}

class _AutoCompleteTextViewState extends State<AutoCompleteTextView> {
  ScrollController scrollController = ScrollController();
  OverlayEntry _overlayEntry;
  LayerLink _layerLink = LayerLink();
  final suggestionsStreamController = new BehaviorSubject<List<String>>();
  List<String> suggestionShowList = List<String>();
  Timer _debounce;
  bool isSearching = true;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (widget.focusNode.hasFocus) {
        this.isSearching = true;
        this._overlayEntry = this._createOverlayEntry();
        Overlay.of(context).insert(this._overlayEntry);
        if(widget?.focusGained != null) widget?.focusGained();
        _onSearchChanged();
      } else {
        this._overlayEntry.remove();
        if(widget?.focusLost != null) widget?.focusLost();
      }
    });
    widget.controller.addListener(_onSearchChanged);
  }

  _onSearchChanged() {
    if (_debounce?.isActive ?? false) {
      _debounce.cancel();
    }
    
    _debounce = Timer(Duration(milliseconds: widget.suggestionsApiFetchDelay), () {
      if (isSearching == true) {
        _getSuggestions(widget.controller.text);
      }
    });
  }

  _getSuggestions(String data) async {
    List<String> list = await widget.getSuggestionsMethod(data ?? "");
    suggestionsStreamController.sink.add(list);
}

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject();
    var size = renderBox.size;
    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: this._layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            child: StreamBuilder<Object>(
              stream: suggestionsStreamController.stream,
              builder: (context, suggestionData) {
                if (suggestionData.hasData) {
                  suggestionShowList = suggestionData.data;
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 200,
                    ),
                    child: ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: suggestionShowList.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            suggestionShowList[index],
                            style: widget.suggestionStyle,
                            textAlign: widget.suggestionTextAlign,
                          ),
                          onTap: () {
                            isSearching = false;
                            widget.controller.text = suggestionShowList[index];
                            suggestionsStreamController.sink.add([]);
                            if (widget.focusNode.hasPrimaryFocus) {
                              widget.focusNode.unfocus();
                            }
                            widget.onTappedSuggestion(widget.controller.text);
                          },
                        );
                      }
                    ),
                  );
                } else {
                  return Container();
                }
              }
            ),
          ),
        ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: this._layerLink,
      child: TextField(
        controller: widget.controller,
        decoration: widget.tfTextDecoration,
        style: widget.tfStyle,
        enabled: widget.tfEnabled,
        cursorColor: widget.tfCursorColor,
        cursorWidth: widget.tfCursorWidth,
        textAlign: widget.tfTextAlign,
        focusNode: widget.focusNode,
        onSubmitted: widget.onSubmitted,
        textInputAction: widget.tfInputAction,
        onChanged: (text) {
          if(widget?.onValueChanged != null) widget?.onValueChanged(text);
          isSearching = true;
          scrollController.animateTo(
            0.0,
            curve: Curves.easeOut,
            duration: const Duration(milliseconds: 300),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    suggestionsStreamController.close();
    scrollController.dispose();
    widget.controller.dispose();
    super.dispose();
  }
}

abstract class AutoCompleteTextInterface {
  void onTappedSuggestion(String suggestion);
}
