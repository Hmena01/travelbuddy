import 'dart:developer' as dev;

class DebugHelper {
  static final Set<String> _activeInstances = <String>{};

  static String createInstance(String componentName) {
    final instanceId =
        '${componentName}_${DateTime.now().millisecondsSinceEpoch}';
    _activeInstances.add(instanceId);

    dev.log(
      'Created instance: $instanceId (Total: ${_activeInstances.length})',
      name: 'DebugHelper',
    );

    return instanceId;
  }

  static void disposeInstance(String instanceId) {
    _activeInstances.remove(instanceId);

    dev.log(
      'Disposed instance: $instanceId (Remaining: ${_activeInstances.length})',
      name: 'DebugHelper',
    );
  }

  static void logActiveInstances() {
    dev.log(
      'Active instances (${_activeInstances.length}): ${_activeInstances.join(', ')}',
      name: 'DebugHelper',
    );
  }

  static int get activeInstanceCount => _activeInstances.length;
}
