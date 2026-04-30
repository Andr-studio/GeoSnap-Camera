abstract class Failure {
  final String message;
  final Exception? exception;

  const Failure(this.message, {this.exception});

  @override
  String toString() => 'Failure: $message ${exception != null ? '($exception)' : ''}';
}

class WatermarkFailure extends Failure {
  const WatermarkFailure(super.message, {super.exception});
}

class Result<T, F extends Failure> {
  final T? _value;
  final F? _failure;
  final bool isSuccess;

  Result.success(this._value)
      : isSuccess = true,
        _failure = null;

  Result.failure(this._failure)
      : isSuccess = false,
        _value = null;

  T get value {
    if (!isSuccess) throw Exception('Cannot get value from a failure result');
    return _value as T;
  }

  F get failure {
    if (isSuccess) throw Exception('Cannot get failure from a success result');
    return _failure as F;
  }

  R fold<R>(R Function(F failure) onFailure, R Function(T value) onSuccess) {
    if (isSuccess) {
      return onSuccess(value);
    } else {
      return onFailure(failure);
    }
  }
}
