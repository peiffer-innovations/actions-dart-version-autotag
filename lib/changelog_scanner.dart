// ignore_for_file: avoid_print

import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';

/// Scans the CHANGELOG contents and can return the changes for a given version.
class ChangelogScanner {
  const ChangelogScanner(
    this.changelog, {
    this.versionLineRegex = r'^#+\s+.*\d+\.\d+\.\d+.*',
    this.versionRegex = r'\d+\.\d+\.\d+(\+\d*)?(-[\w\d]*)?',
  });

  static final Logger _logger = Logger('ChangelogScanner');

  final String changelog;
  final String versionLineRegex;
  final String versionRegex;

  /// Returns the changes from the CHANGELOG for the given version.  Will return
  /// null if the version is not found.
  ///
  /// If [includeMinorVersions] is set to true then the changes from subversions
  /// will be included.  For example, if the version passed in is 2.3 then the
  /// changes from 2.3.* will be included.
  String getChanges(String version) {
    final actualVersionNums = version.split('.');
    final versionNums = List<String>.from(actualVersionNums);
    final includeMinorVersions = actualVersionNums.length < 3;
    while (versionNums.length < 3) {
      versionNums.add('0');
    }
    final semver = Version.parse(
        actualVersionNums.length == 3 ? version : versionNums.join('.'));
    final lines = changelog.split('\n');

    var buf = StringBuffer();
    var found = false;
    for (var line in lines) {
      if (_isVersionLine(line)) {
        final actualVersion = _parseVersion(line);
        if (actualVersion == version) {
          _logger.info(
              '[$version]: Found start of changelog version: $actualVersion');
          found = true;
        } else if (includeMinorVersions) {
          final actualVersion = _parseVersion(line);
          final actualSemver = Version.parse(actualVersion);

          if ((actualVersionNums.length == 1 &&
                  actualSemver.major == semver.major) ||
              (actualVersionNums.length == 2 &&
                  actualSemver.major == semver.major &&
                  actualSemver.minor == semver.minor) ||
              actualVersionNums.length == 3) {
            _logger.info(
                '[$version]: Encountered version to include: $actualVersion');
            buf = StringBuffer(buf.toString().trim());
            buf.write('\n\n\n');
            found = true;
          } else {
            _logger.info('[$version]: Skipping version: $actualVersion');
            found = false;
          }
        } else {
          found = false;
        }
      }

      if (found) {
        buf.write('$line\n');
      }
    }

    if (buf.isEmpty) {
      throw Exception('Version "$version" not found');
    }

    return buf.toString().trim();
  }

  bool _isVersionLine(String line) => RegExp(versionLineRegex).hasMatch(line);

  String _parseVersion(String line) {
    final match = RegExp(versionRegex).firstMatch(line);
    final version = match?.group(0);
    if (version == null) {
      throw Exception('Unable to locate version in: $line');
    }

    return version;
  }
}
