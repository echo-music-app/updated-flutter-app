sealed class Result<T> {
  const Result();
  factory Result.ok(T value) => Ok(value);
  factory Result.error(Exception error) => Err(error);
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
  @override
  String toString() => 'Result<$T>.ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final Exception error;
  @override
  String toString() => 'Result<$T>.error($error)';
}
