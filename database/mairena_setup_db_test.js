//init with $mongo localhost:27017/test mairena_setup_test.js
db = new Mongo().getDB('mairena_db_test');
things={'init': true};
db.things.insert(things);
//Add user auth
if(!db.auth('infantiumongo','1234')){
   db.addUser('infantiumongo','1234');
}

quit();