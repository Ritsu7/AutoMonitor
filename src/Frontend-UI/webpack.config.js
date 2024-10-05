const path = require('path');
const webpack = require('webpack');
const Dotenv = require('dotenv-webpack'); // Import webpack

module.exports = {
    mode: 'development',
    entry: './script.js', // Path to your entry file
    output: {
        filename: 'bundle.js', // Name of the output file
        path: path.resolve(__dirname, 'dist'), // Output directory
    },
    resolve: {
        extensions: ['.js'],
        fallback: {
            "buffer": require.resolve("buffer/"),
        },
    },
    plugins: [
        new webpack.ProvidePlugin({
            Buffer: ['buffer', 'Buffer'],
        }),
        new Dotenv(),
    ],
    devtool: 'source-map', // Enable source maps for easier debugging
};
