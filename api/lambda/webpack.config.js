const path = require('path');
const webpack = require('webpack');
const slsw = require('serverless-webpack');

const config = {
  entry: slsw.lib.entries,
  target: 'node',

  output: {
    libraryTarget: 'commonjs',
    path: path.resolve(`${__dirname}/dist`),
    filename: '[name].js',
  },

  module: {
    rules: [{
      test: /\.elm$/,
      exclude: [/elm-stuff/, /node_modules/],
      use: {
        loader: 'elm-webpack-loader',
        options: {
          forceWatch: true
        }
      }
    }]
  },
};

if (process.env.NODE_ENV === 'production') {
  config.module.loaders.push({
    test: /\.js$/,
    exclude: [/elm-stuff/, /node_modules/],
    loader: 'babel-loader',
    options: {
      presets: 'env'
    },
  });

  config.plugins = config.plugins || [];
  config.plugins.push(new webpack.optimize.UglifyJsPlugin());
}

module.exports = config;
