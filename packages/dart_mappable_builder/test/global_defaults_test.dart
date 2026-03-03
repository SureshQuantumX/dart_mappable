import 'package:test/test.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_mappable_builder/src/builders/mappable_builder.dart';
import 'package:build/build.dart';

import 'utils/test_mappable.dart';

class _DecodeMatcher extends Matcher {
  final Matcher _inner;
  _DecodeMatcher(this._inner);

  @override
  bool matches(dynamic item, Map matchState) {
    String content;
    if (item is List<int>) {
      content = String.fromCharCodes(item);
    } else if (item is String) {
      content = item;
    } else {
      return false;
    }
    var result = _inner.matches(content, matchState);
    return result;
  }

  @override
  Description describe(Description description) => _inner.describe(description);
  
  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map matchState, bool verbose) {
    if (item is List<int>) {
      return _inner.describeMismatch(String.fromCharCodes(item), mismatchDescription, matchState, verbose);
    }
    return _inner.describeMismatch(item, mismatchDescription, matchState, verbose);
  }
}

Matcher decoded(Matcher inner) => _DecodeMatcher(inner);

void main() {
  group('global defaults', () {
    test('generates correct defaults from build.yaml', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {
          'String': '',
          'int': 0,
          'double': 0.0,
          'bool': false,
          'List': [],
          'Map': {},
        },
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();
      
      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';
            
            part 'model.mapper.dart';
            
            @MappableClass()
            class Model with ModelMappable {
              final String a;
              final int b;
              final double c;
              final bool d;
              final List<String> e;
              final Map<String, int> f;
            
              Model(this.a, this.b, this.c, this.d, this.e, this.f);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(allOf([
            contains("Field('a', _\$a, def: r'')"),
            contains("Field('b', _\$b, def: 0)"),
            contains("Field('c', _\$c, def: 0.0)"),
            contains("Field('d', _\$d, def: false)"),
            contains("Field('e', _\$e, def: [])"),
            contains("Field('f', _\$f, def: {})"),
          ])),
        },
        readerWriter: reader,
      );
    });

    test('generates correct defaults from annotation', () async {
      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();
      
      await testBuilder(
        MappableBuilder(BuilderOptions({})),
        {
          'models|lib/model.dart': '''
            @MappableLib(
              useGlobalDefaultsOnMissing: true,
              globalDefaults: {
                'String': 'default',
                'int': 42,
              },
            )
            library my_lib;
            
            import 'package:dart_mappable/dart_mappable.dart';
            
            part 'model.mapper.dart';
            
            @MappableClass()
            class Model with ModelMappable {
              final String a;
              final int b;
            
              Model(this.a, this.b);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(allOf([
            contains("Field('a', _\$a, def: r'default')"),
            contains("Field('b', _\$b, def: 42)"),
          ])),
        },
        readerWriter: reader,
      );
    });

    test('generates no defaults when disabled', () async {
      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();
      
      await testBuilder(
        MappableBuilder(BuilderOptions({'useGlobalDefaultsOnMissing': false})),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';
            
            part 'model.mapper.dart';
            
            @MappableClass()
            class Model with ModelMappable {
              final String a;
            
              Model(this.a);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(isNot(contains("def:")))
        },
        readerWriter: reader,
      );
    });

    test('explicit defaults take precedence', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {
          'String': 'global',
        },
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();
      
      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';
            
            part 'model.mapper.dart';
            
            @MappableClass()
            class Model with ModelMappable {
              final String a;
            
              Model({this.a = 'explicit'});
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(allOf([
            contains("'a'"),
            contains("_\$a"),
            contains("opt: true"),
            contains("def: 'explicit'"),
          ])),
        },
        readerWriter: reader,
      );
    });
  });
}
