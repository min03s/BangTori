const GoogleStrategy = require('passport-google-oauth20').Strategy;
const KakaoStrategy = require('passport-kakao').Strategy;
const NaverStrategy = require('passport-naver').Strategy;
const User = require('../models/User');

module.exports = function(passport) {
  // Google Strategy
  passport.use(new GoogleStrategy({
    clientID: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    callbackURL: "/api/auth/google/callback"
  }, async (accessToken, refreshToken, profile, done) => {
    try {
      let user = await User.findOne({ socialId: profile.id, provider: 'google' });
      
      if (user) {
        return done(null, user);
      } else {
        user = new User({
          socialId: profile.id,
          provider: 'google',
          email: profile.emails[0].value,
          nickname: profile.displayName,
          profileImage: profile.photos[0].value
        });
        await user.save();
        return done(null, user);
      }
    } catch (error) {
      return done(error, null);
    }
  }));

  // Kakao Strategy
  passport.use(new KakaoStrategy({
    clientID: process.env.KAKAO_CLIENT_ID,
    callbackURL: "/api/auth/kakao/callback"
  }, async (accessToken, refreshToken, profile, done) => {
    try {
      let user = await User.findOne({ socialId: profile.id, provider: 'kakao' });
      
      if (user) {
        return done(null, user);
      } else {
        user = new User({
          socialId: profile.id,
          provider: 'kakao',
          email: profile._json.kakao_account.email,
          nickname: profile.displayName,
          profileImage: profile._json.properties.profile_image
        });
        await user.save();
        return done(null, user);
      }
    } catch (error) {
      return done(error, null);
    }
  }));

  // Naver Strategy
  passport.use(new NaverStrategy({
    clientID: process.env.NAVER_CLIENT_ID,
    clientSecret: process.env.NAVER_CLIENT_SECRET,
    callbackURL: "/api/auth/naver/callback"
  }, async (accessToken, refreshToken, profile, done) => {
    try {
      let user = await User.findOne({ socialId: profile.id, provider: 'naver' });
      
      if (user) {
        return done(null, user);
      } else {
        user = new User({
          socialId: profile.id,
          provider: 'naver',
          email: profile.emails[0].value,
          nickname: profile.displayName,
          profileImage: profile._json.profile_image
        });
        await user.save();
        return done(null, user);
      }
    } catch (error) {
      return done(error, null);
    }
  }));
};