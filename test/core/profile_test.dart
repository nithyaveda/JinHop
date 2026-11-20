import 'package:flutter_test/flutter_test.dart';
import 'package:jinhop/core/profile.dart';

void main() {
  test('email validator', () {
    expect(validateEmail(''), isNotNull);
    expect(validateEmail('rana'), isNotNull);
    expect(validateEmail('rana@msu'), isNotNull);
    expect(validateEmail(' rana@msu.edu.my '), isNull);
  });

  test('password validator: 6+ chars with a letter and a number', () {
    expect(validatePassword(''), isNotNull);
    expect(validatePassword('ab1'), isNotNull);
    expect(validatePassword('abcdef'), isNotNull);
    expect(validatePassword('123456'), isNotNull);
    expect(validatePassword('lotus7'), isNull);
    expect(validateConfirmPassword('lotus8', 'lotus7'), 'Passwords do not match');
    expect(validateConfirmPassword('lotus7', 'lotus7'), isNull);
  });

  test('name and motto validators', () {
    expect(validateName(' '), isNotNull);
    expect(validateName('R'), isNotNull);
    expect(validateName('Rana'), isNull);
    expect(validateName('x' * 21), isNotNull);
    expect(validateMotto(''), isNull);
    expect(validateMotto('x' * 41), isNotNull);
  });

  test('profile initial and copyWith', () {
    const p = PlayerProfile(name: 'lotus');
    expect(p.initial, 'L');
    expect(p.copyWith(motto: 'Hop on').motto, 'Hop on');
    expect(p.copyWith(motto: 'Hop on').name, 'lotus');
  });
}
