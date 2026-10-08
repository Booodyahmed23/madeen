import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/failure_mapper.dart';
import 'package:mobile/core/network/api_exception.dart';

void main() {
  AppFailure map(int status, String message, {String? code}) =>
      mapApiExceptionToFailure(
        ApiException(statusCode: status, message: message, code: code),
      );

  test('the entitlement 403s become NoAccessFailure', () {
    expect(
      map(403, 'An active subscription is required'),
      isA<NoAccessFailure>(),
    );
    expect(
      map(403, 'No active subscription covers one or more selected topics'),
      isA<NoAccessFailure>(),
    );
  });

  test('other 403s stay plain ForbiddenFailure and keep their code', () {
    final failure = map(403, 'Admins cannot', code: 'ADMIN_SELF_DELETE');
    expect(failure, isA<ForbiddenFailure>());
    expect(failure, isNot(isA<NoAccessFailure>()));
    expect(failure.code, 'ADMIN_SELF_DELETE');
  });

  test('404 becomes NotFoundFailure', () {
    expect(map(404, 'Not found'), isA<NotFoundFailure>());
  });

  test('400 keeps the code for the screen to translate', () {
    final failure = map(400, 'Wrong', code: 'WRONG_CURRENT_PASSWORD');
    expect(failure, isA<ValidationFailure>());
    expect(failure.code, 'WRONG_CURRENT_PASSWORD');
  });

  test('429 is a ServerFailure with its status', () {
    expect(
      map(429, 'Too Many Requests'),
      isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 429),
    );
  });
}
