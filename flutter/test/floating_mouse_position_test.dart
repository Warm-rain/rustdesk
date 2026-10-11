import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/mobile/widgets/floating_mouse.dart' as mouse;
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class _Input extends Fake implements InputModel {
  Offset? position;
  @override
  Map<String, dynamic>? handleMouse(Map<String, dynamic> evt, Offset offset,
      {bool onExit = false, bool moveCanvas = true, bool edgeScroll = false}) {
    position = offset;
    return {'x': '${offset.dx}', 'y': '${offset.dy}'};
  }
}

class _Canvas extends CanvasModel {
  _Canvas(FFI ffi, this.adjustY) : super(WeakReference(ffi));
  final double adjustY;
  @override
  double getAdjustY() => adjustY;
}

class _FFI extends Fake implements FFI {
  _FFI(double adjustY) {
    ffiModel = FfiModel(WeakReference(this));
    cursorModel = CursorModel(WeakReference(this));
    canvasModel = _Canvas(this, adjustY);
    ffiModel.virtualMouseMode.setShowVirtualMouse(true);
  }
  @override
  final SessionID sessionId = const Uuid().v4obj();
  @override
  late final FfiModel ffiModel;
  @override
  late final CursorModel cursorModel;
  @override
  late final CanvasModel canvasModel;
  @override
  final _Input inputModel = _Input();
}

void main() {
  for (final adjustY in [0.0, 80.0]) {
    testWidgets(
        'floating cursor and forwarded position agree (adjust $adjustY)',
        (tester) async {
      final ffi = _FFI(adjustY);
      const inset = Offset(32, 56);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(400, 700)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.only(left: 32, top: 56),
            child: ChangeNotifierProvider<CursorModel>.value(
              value: ffi.cursorModel,
              child: mouse.FloatingMouse(ffi: ffi),
            ),
          ),
        ),
      ));
      await tester.pump();
      final cursor = find.byType(mouse.CursorPaint);
      final initial = tester.getTopLeft(cursor) - inset;
      final gesture = await tester
          .startGesture(tester.getCenter(find.byIcon(Icons.drag_indicator)));
      await gesture.moveBy(const Offset(30, -20));
      await gesture.moveBy(const Offset(10, 5));
      await tester.pump();
      final visible = tester.getTopLeft(cursor) - inset;
      expect(visible, initial + const Offset(40, -15));
      expect(ffi.inputModel.position, visible - Offset(0, adjustY));
      await gesture.up();
      await tester.pumpWidget(const SizedBox.shrink());
      ffi.cursorModel.disposeImages();
      ffi.cursorModel.dispose();
      ffi.canvasModel.dispose();
    });
  }
}
