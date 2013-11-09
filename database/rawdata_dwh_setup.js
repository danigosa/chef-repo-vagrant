//init with $mongo localhost:27017/test fary_init.js
db = new Mongo().getDB('rawdata_dwh');
things={'init': true};
db.things.insert(things);
//Add user auth
if(!db.auth('infantiumongo','1234')){
   db.addUser('infantiumongo','1234');
}

quit();