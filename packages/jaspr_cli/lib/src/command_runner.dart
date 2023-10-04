import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:mason/mason.dart';
import 'package:pub_updater/pub_updater.dart';

import 'commands/build_command.dart';
import 'commands/clean_command.dart';
import 'commands/create_command.dart';
import 'commands/generate_command.dart';
import 'commands/serve_command.dart';
import 'commands/update_command.dart';
import 'version.dart';

/// The package name.
const packageName = 'jaspr_cli';

/// The executable name.
const executableName = 'jaspr';

/// A [CommandRunner] for the Jaspr CLI.
class JasprCommandRunner extends CompletionCommandRunner<int> {
  JasprCommandRunner() : super(executableName, 'jaspr - A modern web framework for building websites in Dart.') {
    argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the current version info.',
    );
    addCommand(CreateCommand());
    addCommand(ServeCommand());
    addCommand(BuildCommand());
    addCommand(GenerateCommand());
    addCommand(CleanCommand());
    addCommand(UpdateCommand());
  }

  final Logger _logger = Logger();
  final PubUpdater _updater = PubUpdater();

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await runCommand(parse(args)) ?? ExitCode.success.code;
    } on FormatException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    } on ProcessException catch (error) {
      _logger.err(error.message);
      return ExitCode.unavailable.code;
    } catch (error) {
      _logger.err('$error');
      return ExitCode.software.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }

    int? exitCode = ExitCode.unavailable.code;
    var isVersionCommand = topLevelResults['version'] == true;
    if (isVersionCommand) {
      _logger.info(jasprCliVersion);
      exitCode = ExitCode.success.code;
    }
    if (topLevelResults.command?.name != 'update') {
      await _checkForUpdates();
    }
    if (!isVersionCommand) {
      exitCode = await super.runCommand(topLevelResults);
    }
    return exitCode;
  }

  Future<void> _checkForUpdates() async {
    try {
      final latestVersion = await _updater.getLatestVersion(packageName);
      final isUpToDate = jasprCliVersion == latestVersion;
      if (!isUpToDate) {
        _logger.info(wrapBox(
            '${lightYellow.wrap('Update available!')} ${lightCyan.wrap(jasprCliVersion)} \u2192 ${lightCyan.wrap(latestVersion)}\n'
            'Run ${cyan.wrap('$executableName update')} to update'));
      }
    } catch (_) {}
  }
}

String wrapBox(String message) {
  var lines = message.split('\n');
  var lengths = lines.map((l) => l.replaceAll(RegExp('\x1B\\[\\d+m'), '').length).toList();
  var maxLength = lengths.reduce(max);
  var buffer = StringBuffer();
  var hborder = ''.padLeft(maxLength + 8, '═');
  buffer.write('╔$hborder╗\n');
  for (var (i, l) in lines.indexed) {
    var pad = (maxLength + 8 - lengths[i]) / 2;
    var padL = ''.padLeft(pad.floor());
    var padR = ''.padLeft(pad.ceil());
    buffer.write('║$padL$l$padR║\n');
  }
  buffer.write('╚$hborder╝');
  return buffer.toString();
}
