class EmailTakenError(Exception):
    pass


class UsernameTakenError(Exception):
    pass


class InvalidCredentialsError(Exception):
    pass


class AccountDisabledError(Exception):
    pass


class InvalidTokenError(Exception):
    pass


class EmailNotVerifiedError(Exception):
    pass


class InvalidVerificationCodeError(Exception):
    pass


class EmailDeliveryNotConfiguredError(Exception):
    pass


class EmailDeliveryFailedError(Exception):
    pass


class InvalidGoogleTokenError(Exception):
    pass


class GoogleAuthNotConfiguredError(Exception):
    pass


class GoogleAccountConflictError(Exception):
    pass


class MfaRequiredError(Exception):
    pass


class InvalidMfaCodeError(Exception):
    pass


class MfaNotConfiguredError(Exception):
    pass
