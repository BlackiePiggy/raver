export type AppErrorCode =
  | 'network_error'
  | 'http_error'
  | 'parse_error'
  | 'unknown_error';

export type AppError = {
  code: AppErrorCode;
  message: string;
  status?: number;
  requestId?: string;
  retryable: boolean;
};

export function createAppError(error: Partial<AppError> & Pick<AppError, 'code'>): AppError {
  return {
    code: error.code,
    message: error.message ?? 'Something went wrong.',
    requestId: error.requestId,
    retryable: error.retryable ?? false,
    status: error.status,
  };
}

export function isAppError(value: unknown): value is AppError {
  return (
    typeof value === 'object' &&
    value !== null &&
    'code' in value &&
    'message' in value &&
    'retryable' in value
  );
}
