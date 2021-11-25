module.exports = {
  purge: ["./public/**/*.html", "./src/**/*.elm", "./src/**/*.js"],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {},
  },
  variants: {
    extend: {
      display : ['group-hover'],
      backgroundColor: ['disabled']
    },
  },
  plugins: [],
};
