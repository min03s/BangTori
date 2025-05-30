const { body, param } = require('express-validator');

const userValidation = {
  create: [
    body('nickname')
      .trim()
      .isLength({ min: 2, max: 20 })
      .withMessage('닉네임은 2-20자 사이여야 합니다')
      .matches(/^[a-zA-Z0-9가-힣\s]*$/)
      .withMessage('닉네임에는 특수문자를 사용할 수 없습니다')
  ],

  update: [
    param('id').isMongoId().withMessage('유효하지 않은 사용자 ID입니다'),
    body('nickname')
      .optional()
      .trim()
      .isLength({ min: 2, max: 20 })
      .withMessage('닉네임은 2-20자 사이여야 합니다'),
    body('profileColor')
      .optional()
      .matches(/^#[0-9A-F]{6}$/i)
      .withMessage('유효하지 않은 색상 코드입니다')
  ]
};

const roomValidation = {
  create: [
    body('name')
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('방 이름은 1-50자 사이여야 합니다'),
    body('description')
      .optional()
      .trim()
      .isLength({ max: 200 })
      .withMessage('방 설명은 200자 이하여야 합니다'),
    body('ownerId')
      .isMongoId()
      .withMessage('유효하지 않은 사용자 ID입니다')
  ],

  join: [
    body('inviteCode')
      .trim()
      .isLength({ min: 6, max: 6 })
      .withMessage('초대 코드는 6자리여야 합니다')
      .isAlphanumeric()
      .withMessage('초대 코드는 영문자와 숫자만 포함해야 합니다'),
    body('userId')
      .isMongoId()
      .withMessage('유효하지 않은 사용자 ID입니다')
  ],

  update: [
    param('roomId').isMongoId().withMessage('유효하지 않은 방 ID입니다'),
    body('name')
      .optional()
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('방 이름은 1-50자 사이여야 합니다'),
    body('description')
      .optional()
      .trim()
      .isLength({ max: 200 })
      .withMessage('방 설명은 200자 이하여야 합니다'),
    body('ownerId')
      .isMongoId()
      .withMessage('유효하지 않은 사용자 ID입니다')
  ]
};

module.exports = {
  userValidation,
  roomValidation
};