var exec = require('cordova/exec');

exports.coolMethod = function (arg0, success, error) {
    exec(success, error, 'videocall', 'coolMethod', [arg0]);
};

module.exports.new_activity = function(arg0, arg1, arg2, success, error) {
    exec(success, error, 'videocall', "new_activity", [arg0, arg1, arg2]);
};
