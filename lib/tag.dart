import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
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

  var exitCode = 0;

  final parser = ArgParser();
  parser.addFlag(
    'dry-run',
  );
  parser.addOption(
    'path',
    defaultsTo: '.',
  );
  parser.addOption(
    'repository',
  );
  parser.addOption(
    'token',
    mandatory: true,
  );

  final parsed = parser.parse(args ?? []);
  final path = parsed['path'];

  final dryRun = parsed['dry-run'] == true;
  final pubspec = File('$path/pubspec.yaml');

  if (!pubspec.existsSync()) {
    throw Exception('Unable to load [$path/pubspec.yaml] file.');
  }

  final yaml = loadYamlDocument(pubspec.readAsStringSync());

  final version = yaml.contents.value['version']?.toString();

  if (version == null) {
    throw Exception(
      'Unable to find a version attribute in the [$path/pubspec.yaml].',
    );
  }

  final slug = _getRepositorySlug(repository: parsed['repository']);
  final token = parsed['token'];
  var gh = GitHub(auth: Authentication.withToken(token));

  final tags = await gh.repositories.listTags(slug).toList();

  final repo = await gh.repositories.getRepository(slug);

  final branch = await gh.repositories.getBranch(slug, repo.defaultBranch);
  final sha = branch.commit!.sha!;

  await _createTag(
    dryRun: dryRun,
    gh: gh,
    sha: sha,
    slug: slug,
    tags: tags,
    version: version,
  );

  final major = version.split('.').first;
  await _createTag(
    dryRun: dryRun,
    gh: gh,
    sha: sha,
    slug: slug,
    tags: tags,
    version: major,
  );

  exit(exitCode);
}

Future<void> _createTag({
  required bool dryRun,
  required GitHub gh,
  required String sha,
  required RepositorySlug slug,
  required List<Tag> tags,
  required String version,
}) async {
  Tag? tag;
  for (var t in tags) {
    if (t.name == 'v$version') {
      tag = t;
      _logger.info('Tag exists: ${t.name}');
      break;
    }
  }

  if (!dryRun) {
    if (tag != null) {
      final response = await gh.request(
        'delete',
        '/repos/${slug.owner}/${slug.name}/git/refs/tags/${tag.name}',
      );
      if (response.statusCode >= 300) {
        throw Exception('Unable to get response for deleting tag.');
      }
      _logger.info('Deleted Tag: [v$version]');
    }

    final response = await gh.request(
      'post',
      '/repos/${slug.owner}/${slug.name}/git/refs',
      body: utf8.encode(
        json.encode(
          {
            'ref': 'refs/tags/v$version',
            'sha': sha,
          },
        ),
      ),
    );
    if (response.statusCode >= 300) {
      throw Exception('Unable to get response for creating tag.');
    }

    _logger.info('Created Tag: [v$version]');
  }
}

RepositorySlug _getRepositorySlug({
  String? repository,
}) {
  RepositorySlug? slug;

  if (repository != null && repository.trim().isNotEmpty) {
    var repo = repository;

    slug = RepositorySlug.full(repo);
    _logger.info('Discovered CLI SLUG: $repo');
  } else if (Platform.environment['GITHUB_ACTION_REPOSITORY']?.isNotEmpty ==
          true &&
      Platform.environment['GITHUB_ACTION_REPOSITORY'] != '/') {
    var repo = Platform.environment['GITHUB_ACTION_REPOSITORY']!;

    slug = RepositorySlug.full(repo);
    _logger.info('Discovered ENV SLUG: $repo');
  } else {
    var ghResult = Process.runSync(
      'git',
      ['remote', 'show', 'origin'],
    );
    var ghOutput = ghResult.stdout;

    var regex = RegExp(
      r'Push[^:]*:[^:]*:(?<org>[^\/]*)\/(?<repo>[^\n\.\/]*)',
    );
    var matches = regex.allMatches(ghOutput.toString());

    for (var match in matches) {
      var org = match.namedGroup('org');
      var repo = match.namedGroup('repo');

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
