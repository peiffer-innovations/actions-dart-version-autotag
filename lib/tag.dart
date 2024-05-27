// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_version_autotag/changelog_scanner.dart';
import 'package:github/github.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';

final _logger = Logger('main');
Future<void> main(List<String>? args) async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
    if (record.error != null) {
      print('${record.error}');
    }
    if (record.stackTrace != null) {
      print('${record.stackTrace}');
    }
  });

  final parser = ArgParser();
  parser.addOption(
    'changelog',
    defaultsTo: 'true',
  );
  parser.addOption(
    'major',
    defaultsTo: 'true',
  );
  parser.addOption(
    'minor',
    defaultsTo: 'true',
  );
  parser.addFlag('dry-run');
  parser.addOption(
    'overwrite',
    defaultsTo: 'true',
  );
  parser.addOption(
    'path',
    defaultsTo: '.',
  );
  parser.addOption(
    'prefix',
    defaultsTo: 'v',
  );
  parser.addOption('repository');
  parser.addOption(
    'token',
    abbr: 't',
    defaultsTo: Platform.environment['GITHUB_TOKEN'],
  );

  final parsed = parser.parse(args ?? []);
  final path = parsed['path'];

  final useChangelog = parsed['changelog']?.toString().toLowerCase() == 'true';
  final useMajor = parsed['major']?.toString().toLowerCase() == 'true';
  final useMinor = parsed['minor']?.toString().toLowerCase() == 'true';
  final dryRun = parsed['dry-run'] == true;
  final overwrite = parsed['overwrite']?.toString().toLowerCase() == 'true';
  final prefix = parsed['prefix'];
  final pubspec = File('$path/pubspec.yaml');

  if (!pubspec.existsSync()) {
    throw Exception('Unable to load [$path/pubspec.yaml] file.');
  }

  String? changelog;

  if (useChangelog) {
    final file = File('$path/CHANGELOG.md');
    if (!file.existsSync()) {
      throw Exception('Unable to load [$path/CHANGELOG.md] file.');
    }

    changelog = file.readAsStringSync();
  }

  final yaml = loadYamlDocument(pubspec.readAsStringSync());

  final version = yaml.contents.value['version']?.toString();

  if (version == null) {
    throw Exception(
      'Unable to find a version attribute in the [$path/pubspec.yaml].',
    );
  }

  final slug = _getRepositorySlug(repository: parsed['repository']);
  final token = parsed['token']?.toString();
  if (token == null || token.isEmpty) {
    throw Exception('Unable to find a GitHub token.');
  }

  final options = {
    'changelog': useChangelog,
    'dryRun': dryRun,
    'major': useMajor,
    'minor': useMinor,
    'overwrite': overwrite,
    'path': path,
    'prefix': prefix,
    'slug': slug,
    'version': version,
  };
  _logger.info('Options:');
  for (var entry in options.entries) {
    _logger.info('  * [${entry.key}]: ${entry.value}');
  }
  _logger.info('');

  final gh = GitHub(auth: Authentication.withToken(token));

  final tags = await gh.repositories.listTags(slug).toList();
  final repo = await gh.repositories.getRepository(slug);

  final branch = await gh.repositories.getBranch(slug, repo.defaultBranch);
  final sha = branch.commit!.sha!;

  final tagCreated = await _createTag(
    changelog: changelog,
    dryRun: dryRun,
    gh: gh,
    overwrite: overwrite,
    prefix: prefix,
    sha: sha,
    slug: slug,
    tags: tags,
    version: version,
  );

  final major = version.split('.').first;
  if (tagCreated && useMajor) {
    await _createTag(
      changelog: changelog,
      dryRun: dryRun,
      gh: gh,
      prefix: prefix,
      sha: sha,
      slug: slug,
      tags: tags,
      version: major,
    );
  }

  if (tagCreated && useMinor) {
    final minor = version.split('.')[1];
    await _createTag(
      changelog: changelog,
      dryRun: dryRun,
      gh: gh,
      prefix: prefix,
      sha: sha,
      slug: slug,
      tags: tags,
      version: '$major.$minor',
    );
  }

  exit(exitCode);
}

Future<bool> _createTag({
  String? changelog,
  required bool dryRun,
  required GitHub gh,
  bool overwrite = true,
  required String prefix,
  required String sha,
  required RepositorySlug slug,
  required List<Tag> tags,
  required String version,
}) async {
  var result = false;
  Tag? tag;
  final tagName = '$prefix$version';

  for (var t in tags) {
    if (t.name == tagName) {
      tag = t;
      _logger.info('Tag exists: ${t.name}');
      break;
    }
  }

  if (!overwrite && tag != null) {
    _logger.info('Aborting because tag exists and overwrite is false.');
  } else {
    final cl = changelog;
    String? changes;
    if (cl != null) {
      _logger.info('Looking for changes for tag: $tagName');

      final scanner = ChangelogScanner(cl);
      changes = '''
Release

${scanner.getChanges(version)}
''';

      _logger.info('''
[CHANGELOG]: $version

$changes''');
    }

    if (dryRun) {
      result = true;
      _logger.info('Dry Run Complete: [$tagName]');
    } else {
      if (tag != null) {
        final response = await gh.request(
          'delete',
          '/repos/${slug.owner}/${slug.name}/git/refs/tags/${tag.name}',
        );
        if (response.statusCode >= 300) {
          throw Exception('Unable to get response for deleting tag.');
        }
        _logger.info('Deleted Tag: [$tagName]');
      }

      var response = await gh.request(
        'post',
        '/repos/${slug.owner}/${slug.name}/git/tags',
        body: utf8.encode(
          json.encode(
            {
              if (changes != null) 'message': changes,
              'object': sha,
              'tag': tagName,
              'type': 'commit',
            },
          ),
        ),
      );
      if (response.statusCode >= 300) {
        _logger.severe('''Error on response:
Code: ${response.statusCode}
Body:
${response.body}
''');
        throw Exception('Unable to get response for creating tag.');
      }

      _logger.info('Created Ref for Tag: [$tagName]');

      final responseBody = json.decode(response.body);
      final tagSha = responseBody['sha'];
      response = await gh.request(
        'post',
        '/repos/${slug.owner}/${slug.name}/git/refs',
        body: utf8.encode(
          json.encode(
            {
              'ref': 'refs/tags/$tagName',
              'sha': tagSha,
            },
          ),
        ),
      );
      if (response.statusCode >= 300) {
        _logger.severe('''Error on response:
Code: ${response.statusCode}
Body:
${response.body}
''');
        throw Exception('Unable to get response for creating tag.');
      }

      _logger.info('Created Tag: [$tagName]');
      result = true;
    }
  }

  return result;
}

RepositorySlug _getRepositorySlug({
  String? repository,
}) {
  RepositorySlug? slug;

  if (repository != null && repository.trim().isNotEmpty) {
    final repo = repository;

    slug = RepositorySlug.full(repo);
    _logger.info('Discovered CLI SLUG: $repo');
  } else if (Platform.environment['GITHUB_ACTION_REPOSITORY']?.isNotEmpty ==
      true) {
    final repo = Platform.environment['GITHUB_ACTION_REPOSITORY']!;

    slug = RepositorySlug.full(repo);
    _logger.info('Discovered ENV SLUG: $repo');
  } else {
    final ghResult = Process.runSync(
      'git',
      ['remote', 'show', 'origin'],
    );
    final ghOutput = ghResult.stdout;

    final regex = RegExp(
      r'Push[^:]*:[^:]*:(?<org>[^\/]*)\/(?<repo>[^\n\.\/]*)',
    );
    final matches = regex.allMatches(ghOutput.toString());

    for (var match in matches) {
      final org = match.namedGroup('org');
      final repo = match.namedGroup('repo');

      if (org != null && repo != null) {
        slug = RepositorySlug(org, repo);

        _logger.info('Discovered SLUG: $org/$repo');
        break;
      }
    }
  }

  if (slug == null) {
    throw Exception('Unable to determine GitHub SLUG');
  }

  return slug;
}
