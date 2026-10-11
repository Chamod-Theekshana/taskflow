import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/utils/uuid.dart';

void main() {
  test('new ids are random version 4 UUIDs', () {
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final ids = {for (var i = 0; i < 1000; i++) newUuid()};
    expect(ids, hasLength(1000));
    expect(ids.every(pattern.hasMatch), isTrue);
  });
}
