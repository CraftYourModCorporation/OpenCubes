<<<<<<< HEAD

var app = {
    controllers: {},
    models: {},
    init: function(cb) {
        require('./utils');
        var timer = new Date().getTime();
        var express = require('express');
        var http = require('http');
        var path = require('path');
        var router = require('./router');
        var config = require('./config');
        var fs = require('fs');
        var ECT = require('ect');
        var lessMiddleware = require('less-middleware');
        var utils = require('./controllers/utils.js');
        var flash = require('express-flash');
        var passport = require('passport');

        require('colors');
        console.log(('  Info - Trying to run server at ' + config.ip.bold + ' throught ' + config.port.bold).yellow);
        console.log(('  Info - Loading dependencies took ' + (new Date().getTime() - timer +'').bold + ' ms').cyan);

        var mongoose = require('mongoose');
        mongoose.connect(config.db_uri, config.db_opt, function(err) {
            if (err) return console.log(('  Error - Can\'t connect to mongodb').red);
            var timer2 = new Date().getTime();
            // Bootstrap models
            var models_path = __dirname + '/models';
            fs.readdirSync(models_path).forEach(function(file) {
                if (~file.indexOf('.js')) require(models_path + '/' + file);
            });
            // Bootstrap models
            var controllers_path = __dirname + '/controllers';
            fs.readdirSync(controllers_path).forEach(function(file) {
                if (~file.indexOf('.js')) {
                    //  console.log(file.slice(0,-3));
                    app.controllers[file.slice(0, - 3)] = require(controllers_path + '/' + file);
                }
            });

            console.log(('  Info - Bootstraping took ' + (new Date().getTime() - timer2 +'').bold + ' ms').cyan);

            var server;
            app.server = server = express();
            server.set('port', config.port);
            server.set('ip', config.ip);
            server.set('views', path.join(__dirname, 'views'));
            server.set('view engine', 'html');
            server.use(express.favicon());
            server.use(express.logger('dev'));
            server.use(express.json());
            server.use(express.urlencoded());
            server.use(express.methodOverride());
            server.use(express.cookieParser(config.securitySalt));
            server.use(express.session());
            server.use(flash());
            require('./passport')(passport, config);
            // use passport session
            server.use(passport.initialize());
            server.use(passport.session());
            server.use(function(req, res, next) {
                res.locals.user = req.user;
                next();
            })
            app.passport = passport;

            var ectRenderer = ECT({
                watch: true,
                root: __dirname + '/views',
            });
            server.engine('.ect', ectRenderer.render);
            server.use(lessMiddleware({
                src: __dirname + "/less",
                dest: __dirname.getParent() + "/public/css",
                // if you're using a different src/dest directory, you
                // MUST include the prefex, which matches the dest
                // public directory
                prefix: "/css",
                // force true recompiles on every request... not the
                // best for production, but fine in debug while working
                // through changes
                force: config.env === 'dev'
            }));

            server.use(express.static(path.join(__dirname.getParent(), 'public')));
            server.use({uploadDir:__dirname.getParent()+'/temp'});
            server.use(server.router);
            server.use(utils.notfound);

            // development only
            if ('development' == server.get('env')) {
                server.use(express.errorHandler());
            }

            router(app);


            http.createServer(server).listen(server.get('port'), server.get('ip'), function() {
                console.log(('  Info - Express server listening on port ' + server.get('port').bold + ' in ' + (new Date().getTime() - timer + '').bold + ' ms').green);
                cb();
            });
        });

    }
=======
String.prototype.getParent = function () {
	var replaced = this.replace(new RegExp("\\\\", "g"), '/');
	console.log('replaced:'+replaced);
	var index = replaced.lastIndexOf('/');
	console.log('index:',index);
	return replaced.substring(0, index);
};
Object.defineProperty(Array.prototype, "in", {
	enumerable: false,
	configurable: false,
	writable: false,
	value: function (value, def) {
		return this.indexOf(value) !== -1 ? value : def;
	}
});
Object.defineProperty(Array.prototype, "findIn", {
	enumerable: false,
	configurable: false,
	writable: false,
	value: function (obj) {
		var index = -1; // not found initially
		var keys = Object.keys(obj);
		// filter the collection with the given criterias
		var arr = this;

		var result = arr.filter(function (doc, idx) {
			// keep a counter of matched key/value pairs
			var matched = 0;

			// loop over criteria
			for (var i = keys.length - 1; i >= 0; i--) {
				if (doc[keys[i]] === obj[keys[i]]) {
					matched++;

					// check if all the criterias are matched
					if (matched === keys.length) {
						index = idx;
						return arr[idx];
					}
				}
			}
		});
		return index === -1 ? undefined : arr[index];
	}
});
var app = {
	controllers: {},
	models: {},
	init: function (cb) {

		var timer = new Date().getTime();
		var express = require('express');
		var http = require('http');
		var path = require('path');
		var router = require('./router');
		var config = require('./config');
		var fs = require('fs');
		var ECT = require('ect');
		var lessMiddleware = require('less-middleware');
		var utils = require('./controllers/utils.js');
		var flash = require('express-flash');
		var passport = require('passport');

		require('colors');
		console.log(('  Info - Trying to run server at ' + config.ip.bold + ' throught ' + config.port.bold).yellow);
		console.log(('  Info - Loading dependencies took ' + (new Date().getTime() - timer + '').bold + ' ms').cyan);
		console.log(('  Debug - Current dir: ' + __dirname.bold).cyan);

		var mongoose = require('mongoose');
		mongoose.connect(config.db_uri, config.db_opt, function (err) {
			if (err) return console.log(('  Error - Can\'t connect to mongodb').red);
			var timer2 = new Date().getTime();
			// Bootstrap models
			var models_path = __dirname + '/models';
			fs.readdirSync(models_path).forEach(function (file) {
				if (~file.indexOf('.js')) require(models_path + '/' + file);
			});
			// Bootstrap models
			var controllers_path = __dirname + '/controllers';
			fs.readdirSync(controllers_path).forEach(function (file) {
				if (~file.indexOf('.js')) {
					//  console.log(file.slice(0,-3));
					app.controllers[file.slice(0, -3)] = require(controllers_path + '/' + file);
				}
			});

			console.log(('  Info - Bootstraping took ' + (new Date().getTime() - timer2 + '').bold + ' ms').cyan);

			var server;
			app.server = server = express();
			server.set('port', config.port);
			server.set('ip', config.ip);
			server.set('views', path.join(__dirname, 'views'));
			server.set('view engine', 'html');
			server.use(express.favicon());
			server.use(express.logger('dev'));
			server.use(express.json());
			server.use(express.urlencoded());
			server.use(express.methodOverride());
			server.use(express.cookieParser(config.securitySalt));
			server.use(express.session());
			server.use(flash());
			require('./passport')(passport, config);
			// use passport session
			server.use(passport.initialize());
			server.use(passport.session());
			server.use(function (req, res, next) {
				res.locals.user = req.user;
				next();
			})
			app.passport = passport;

			var ectRenderer = ECT({
				watch: true,
				root: __dirname + '/views',
			});
			server.engine('.ect', ectRenderer.render);
			var dest = __dirname.getParent() + "/public/css";
			console.log('dest:'+dest);
			console.log('parent:'+__dirname.getParent());
			server.use(lessMiddleware({
				src: __dirname + "/less",
				dest: dest,
				// if you're using a different src/dest directory, you
				// MUST include the prefex, which matches the dest
				// public directory
				prefix: "/css",
				// force true recompiles on every request... not the
				// best for production, but fine in debug while working
				// through changes
				force: config.env === 'dev',
				debug: true
			}));

			server.use(express.static(path.join(__dirname.getParent(), 'public')));
			server.use({
				uploadDir: __dirname.getParent() + '/temp'
			});
			server.use(server.router);
			server.use(utils.notfound);

			// development only
			if ('development' == server.get('env')) {
				server.use(express.errorHandler());
			}

			router(app);


			http.createServer(server).listen(server.get('port'), server.get('ip'), function () {
				console.log(('  Info - Express server listening on port ' + server.get('port').bold + ' in ' + (new Date().getTime() - timer + '').bold + ' ms').green);
				cb();
			});
		});

	}
>>>>>>> 80e22bb8a0a6c679b94c02d97a2fccf80ccca982


};

module.exports = app;