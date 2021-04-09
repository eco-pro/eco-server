const path = require('path');
const webpack = require('webpack');
const slsw = require('serverless-webpack');
const filewatcherPlugin = require("filewatcher-webpack-plugin");

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
        }
      }
    }]
  },
  plugins: [
    new filewatcherPlugin({watchFileRegex: ['../shared/**/*.js', '../shared/**/*.elm']})
  ]
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
