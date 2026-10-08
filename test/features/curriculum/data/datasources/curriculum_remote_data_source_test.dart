import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/curriculum/data/datasources/curriculum_remote_data_source.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final Object Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _program(String id, int order) => {
  'id': id,
  'name': id,
  'description': null,
  'order': order,
  'isPublished': true,
};

void main() {
  test('programs are read from every page of { data, meta }', () async {
    final adapter = _Adapter((options) {
      final page = options.queryParameters['page'] as int;
      return {
        'data': [_program('p$page', 2 - page)],
        'meta': {'page': page, 'limit': 100, 'total': 2, 'totalPages': 2},
      };
    });
    final source = CurriculumRemoteDataSource(
      ApiClient(Dio()..httpClientAdapter = adapter),
    );

    final programs = await source.getPrograms();

    expect(adapter.requests.map((r) => r.path).toSet(), {
      '/curriculum/programs',
    });
    expect(adapter.requests.map((r) => r.queryParameters), [
      {'page': 1, 'limit': 100},
      {'page': 2, 'limit': 100},
    ]);
    // Sorted by `order`.
    expect(programs.map((p) => p.id), ['p2', 'p1']);
  });

  test('the tree comes from /curriculum/programs/:id/tree', () async {
    final adapter = _Adapter((_) => {..._program('p1', 0), 'parts': []});
    final source = CurriculumRemoteDataSource(
      ApiClient(Dio()..httpClientAdapter = adapter),
    );

    final tree = await source.getProgramTree('p1');

    expect(adapter.requests.single.path, '/curriculum/programs/p1/tree');
    expect(tree.program.id, 'p1');
  });
}
