import 'package:test/test.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_mappable_builder/src/builders/mappable_builder.dart';
import 'package:build/build.dart';


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
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is List<int>) {
      return _inner.describeMismatch(
        String.fromCharCodes(item),
        mismatchDescription,
        matchState,
        verbose,
      );
    }
    return _inner.describeMismatch(
      item,
      mismatchDescription,
      matchState,
      verbose,
    );
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
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains("Field('a', _\$a, def: r'')"),
              contains("Field('b', _\$b, def: 0)"),
              contains("Field('c', _\$c, def: 0.0)"),
              contains("Field('d', _\$d, def: false)"),
              contains("Field('e', _\$e, def: [])"),
              contains("Field('f', _\$f, def: {})"),
            ]),
          ),
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
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains("Field('a', _\$a, def: r'default')"),
              contains("Field('b', _\$b, def: 42)"),
            ]),
          ),
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
          'models|lib/model.mapper.dart': decoded(isNot(contains('def:'))),
        },
        readerWriter: reader,
      );
    });

    test('generates const defaults for custom @MappableClass types', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-', 'int': 0},
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
            class UserData with UserDataMappable {
              final String userId;
              final String dummyValue;

              UserData(this.userId, this.dummyValue);
            }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final UserData userData;

              Model(this.name, this.userData);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains("def: r'-'"),
              contains("def: const UserData(r'-', r'-')"),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });

    test(
      'generates const defaults for nested custom @MappableClass types',
      () async {
        var options = {
          'useGlobalDefaultsOnMissing': true,
          'globalDefaults': {'String': '-', 'int': 0},
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
            class Inner with InnerMappable {
              final String value;
              Inner(this.value);
            }

            @MappableClass()
            class Outer with OuterMappable {
              final Inner inner;
              final int count;
              Outer(this.inner, this.count);
            }

            @MappableClass()
            class Root with RootMappable {
              final Outer outer;
              final String label;
              Root(this.outer, this.label);
            }
          ''',
          },
          outputs: {
            'models|lib/model.mapper.dart': decoded(
              allOf([
                // Inner's `value` field gets String default
                contains("def: r'-'"),
                // Outer's `inner` field gets a const Inner default
                contains("def: const Inner(r'-')"),
                // Root's `outer` field gets a nested const Outer default
                contains("def: const Outer(const Inner(r'-'), 0)"),
              ]),
            ),
          },
          readerWriter: reader,
        );
      },
    );

    test(
      'skips custom class default when required param has no default',
      () async {
        var options = {
          'useGlobalDefaultsOnMissing': true,
          'globalDefaults': {'String': '-'},
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
            class NoDefault with NoDefaultMappable {
              final String name;
              final Uri uri;
              NoDefault(this.name, this.uri);
            }

            @MappableClass()
            class Model with ModelMappable {
              final String label;
              final NoDefault data;
              Model(this.label, this.data);
            }
          ''',
          },
          outputs: {
            'models|lib/model.mapper.dart': decoded(
              allOf([
                contains("def: r'-'"),
                // NoDefault can't be auto-generated because Uri has no global default
                isNot(contains('def: const NoDefault')),
              ]),
            ),
          },
          readerWriter: reader,
        );
      },
    );

    test('generates custom class defaults with named parameters', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-', 'int': 0},
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
            class Config with ConfigMappable {
              final String host;
              final int port;
              Config({required this.host, required this.port});
            }

            @MappableClass()
            class Model with ModelMappable {
              final Config config;
              Model(this.config);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            contains("def: const Config(host: r'-', port: 0)"),
          ),
        },
        readerWriter: reader,
      );
    });

    test('explicit defaults take precedence', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': 'global'},
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
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains("'a'"),
              contains('_\$a'),
              contains('opt: true'),
              contains("def: 'explicit'"),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });

    test('does not generate default for enum types without config', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            enum Status { active, inactive, pending }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final Status status;

              Model(this.name, this.status);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains("def: r'-'"),
              isNot(contains('def: Status')),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });

    test('skips custom class default when enum field has no default', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-', 'int': 0},
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            enum Priority { low, medium, high }

            @MappableClass()
            class Task with TaskMappable {
              final String title;
              final Priority priority;

              Task({required this.title, required this.priority});
            }

            @MappableClass()
            class Model with ModelMappable {
              final Task task;

              Model(this.task);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            isNot(contains('def: const Task')),
          ),
        },
        readerWriter: reader,
      );
    });

    test('uses enumKeyMissingDefaultValue none when configured', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
        'enumKeyMissingDefaultValue': 'none',
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            enum Status { none, active, inactive }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final Status status;

              Model(this.name, this.status);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            contains('def: Status.none'),
          ),
        },
        readerWriter: reader,
      );
    });

    test('uses enumKeyMissingDefaultValue none inside custom class default', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
        'enumKeyMissingDefaultValue': 'none',
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            enum Priority { none, low, medium, high }

            @MappableClass()
            class Config with ConfigMappable {
              final String label;
              final Priority priority;

              Config({required this.label, required this.priority});
            }

            @MappableClass()
            class Model with ModelMappable {
              final Config config;

              Model(this.config);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            contains(
              "def: const Config(label: r'-', priority: Priority.none)",
            ),
          ),
        },
        readerWriter: reader,
      );
    });

    test('skips DateTime fields (no const constructor)', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
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
              final String name;
              final DateTime createdAt;

              Model(this.name, this.createdAt);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains("def: r'-'"),
              isNot(contains('def: DateTime')),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });

    test('uses configurable enumKeyMissingDefaultValue from build.yaml', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
        'enumKeyMissingDefaultValue': 'unknown',
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            enum Status { active, unknown, inactive }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final Status status;

              Model(this.name, this.status);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            contains('def: Status.unknown'),
          ),
        },
        readerWriter: reader,
      );
    });

    test('skips nullable enum fields', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            enum Status { active, inactive }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final Status? status;

              Model(this.name, this.status);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains("def: r'-'"),
              isNot(contains('def: Status')),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });

    test('no default when enumKeyMissingDefaultValue not found in enum', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
        'enumKeyMissingDefaultValue': 'unknown',
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            enum Status { active, inactive, pending }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final Status status;

              Model(this.name, this.status);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            isNot(contains('def: Status')),
          ),
        },
        readerWriter: reader,
      );
    });

    test('enum decoder uses enumFallbackValue for unknown values', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'enumFallbackValue': 'unknown',
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            @MappableEnum()
            enum MfType { unknown, lumpsum, sip, redemption }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains('return MfType.values[0]'),
              isNot(contains('throw MapperException.unknownEnumValue')),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });

    test('enum decoder throws when enumFallbackValue not found in enum', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'enumFallbackValue': 'unknown',
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            @MappableEnum()
            enum MfType { lumpsum, sip, redemption }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            contains('throw MapperException.unknownEnumValue'),
          ),
        },
        readerWriter: reader,
      );
    });

    test('enumKeyMissingDefaultValue and enumFallbackValue work independently', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
        'enumKeyMissingDefaultValue': 'none',
        'enumFallbackValue': 'unknown',
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            @MappableEnum()
            enum MfType { none, unknown, lumpsum, sip, redemption }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final MfType mfType;

              Model(this.name, this.mfType);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            allOf([
              // Missing field default uses enumKeyMissingDefaultValue ('none')
              contains('def: MfType.none'),
              // Unknown value decoder uses enumFallbackValue ('unknown') — index 1
              contains('return MfType.values[1]'),
              isNot(contains('throw MapperException.unknownEnumValue')),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });

    test('enumKeyMissingDefaultValue takes priority over annotation defaultValue for missing fields', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
        'enumKeyMissingDefaultValue': 'inactive',
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            @MappableEnum(defaultValue: Status.pending)
            enum Status { active, inactive, pending }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final Status status;

              Model(this.name, this.status);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            allOf([
              // Missing field uses enumKeyMissingDefaultValue ('inactive'), not annotation ('pending')
              contains('def: Status.inactive'),
              // Decoder default still uses annotation defaultValue ('pending') for unknown values
              contains('return Status.values[2]'),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });

    test('annotation defaultValue used for missing field when no enumKeyMissingDefaultValue configured', () async {
      var options = {
        'useGlobalDefaultsOnMissing': true,
        'globalDefaults': {'String': '-'},
      };

      final reader = TestReaderWriter(rootPackage: 'models');
      await reader.testing.loadIsolateSources();

      await testBuilder(
        MappableBuilder(BuilderOptions(options)),
        {
          'models|lib/model.dart': '''
            import 'package:dart_mappable/dart_mappable.dart';

            part 'model.mapper.dart';

            @MappableEnum(defaultValue: Status.pending)
            enum Status { active, inactive, pending }

            @MappableClass()
            class Model with ModelMappable {
              final String name;
              final Status status;

              Model(this.name, this.status);
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            contains('def: Status.pending'),
          ),
        },
        readerWriter: reader,
      );
    });

    test('full scenario: snakeCase + enums + custom class with named params', () async {
      var options = {
        'caseStyle': 'snakeCase',
        'useGlobalDefaultsOnMissing': true,
        'enumKeyMissingDefaultValue': 'unknown',
        'enumFallbackValue': 'unknown',
        'globalDefaults': {
          'String': '-',
          'int': 0,
          'double': 0.0,
          'bool': false,
          'num': 0,
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
            class UserData with UserDataMappable {
              final String userId;
              final String dummyValue;

              const UserData({
                required this.userId,
                required this.dummyValue,
              });
            }

            enum FrontendOrderStatus { unknown, placed, confirmed, rejected }

            enum MfType { unknown, lumpsum, sip, redemption }

            @MappableClass()
            class MfOrdersData with MfOrdersDataMappable {
              final String schemeName;
              final double amount;
              final FrontendOrderStatus frontendStatus;
              final MfType mfType;
              final String userId;
              final num dummyValue;
              final UserData userData;

              const MfOrdersData({
                required this.schemeName,
                required this.amount,
                required this.frontendStatus,
                required this.mfType,
                required this.userId,
                required this.dummyValue,
                required this.userData,
              });
            }
          ''',
        },
        outputs: {
          'models|lib/model.mapper.dart': decoded(
            allOf([
              contains("def: r'-'"),
              contains('def: 0.0'),
              contains('def: FrontendOrderStatus.unknown'),
              contains('def: MfType.unknown'),
              contains('def: 0'),
              contains("def: const UserData(userId: r'-', dummyValue: r'-')"),
            ]),
          ),
        },
        readerWriter: reader,
      );
    });
  });
}
