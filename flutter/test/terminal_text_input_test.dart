import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('terminal attaches text input to its Flutter view and sends typing',
      (tester) async {
    final terminal = Terminal();
    final output = <String>[];
    terminal.onOutput = output.add;
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TerminalView(terminal, focusNode: focusNode)),
    ));
    focusNode.requestFocus();
    await tester.pump();

    final clients = tester.testTextInput.log
        .where((call) => call.method == 'TextInput.setClient');
    expect(clients, isNotEmpty);
    final arguments = clients.last.arguments as List<dynamic>;
    final configuration = arguments[1] as Map<dynamic, dynamic>;
    final viewId = View.of(tester.element(find.byType(TerminalView))).viewId;
    expect(configuration['viewId'], viewId);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'abc123'),
    );
    await tester.pump();
    expect(output.join(), 'abc123');
  });
}
