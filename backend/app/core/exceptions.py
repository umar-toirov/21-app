from fastapi import HTTPException, status


class AppError(HTTPException):
    def __init__(self, code: str, detail: str, status_code: int = status.HTTP_400_BAD_REQUEST):
        super().__init__(status_code=status_code, detail={"code": code, "message": detail})


class NotFoundError(AppError):
    def __init__(self, resource: str):
        super().__init__("NOT_FOUND", f"{resource} not found", status.HTTP_404_NOT_FOUND)


class ForbiddenError(AppError):
    def __init__(self, detail: str = "Forbidden"):
        super().__init__("FORBIDDEN", detail, status.HTTP_403_FORBIDDEN)


class ConflictError(AppError):
    def __init__(self, detail: str):
        super().__init__("CONFLICT", detail, status.HTTP_409_CONFLICT)
