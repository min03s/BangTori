class ResponseHelper {
  static success(res, data = null, message = 'Success', status = 200) {
    return res.status(status).json({
      success: true,
      message,
      data
    });
  }

  static error(res, message = 'Error', status = 400, errors = null) {
    return res.status(status).json({
      success: false,
      message,
      errors
    });
  }

  static created(res, data, message = 'Created successfully') {
    return this.success(res, data, message, 201);
  }

  static notFound(res, message = 'Resource not found') {
    return this.error(res, message, 404);
  }

  static unauthorized(res, message = 'Unauthorized') {
    return this.error(res, message, 401);
  }

  static forbidden(res, message = 'Forbidden') {
    return this.error(res, message, 403);
  }

  static validationError(res, errors) {
    return this.error(res, 'Validation failed', 422, errors);
  }

  static serverError(res, message = 'Internal server error') {
    return this.error(res, message, 500);
  }
}

module.exports = ResponseHelper;