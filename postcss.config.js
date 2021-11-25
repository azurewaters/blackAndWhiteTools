const env = process.env.NODE_ENV || "development";

const productionPlugins = [];

module.exports = {
  plugins: [
    require("tailwindcss"),
    require("autoprefixer"),
    ...(env === "production" ? productionPlugins : []),
  ],
};
