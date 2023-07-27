const express = require('express');
const morgan = require('morgan');
const session = require('cookie-session');
const { SERVER_SESSION_SECRET, PORT } = require('./config.js');

let app = express();
app.set('view engine', 'ejs');
app.use(morgan('tiny'));
app.use(session({ secret: SERVER_SESSION_SECRET, maxAge: 24 * 60 * 60 * 1000 }));
app.use(require('./routes/auth.js'));
app.use(require('./routes/shares.js'));
app.use(require('./routes/token.js'));
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).render('error', { user: req.session.user, error: err });
})
app.listen(PORT, () => console.log(`Server listening on port ${PORT}...`));
