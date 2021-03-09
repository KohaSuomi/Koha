//package RemoteAPIs.Driver
if (typeof RemoteAPIs == "undefined") {
    this.RemoteAPIs = {}; //Set the global package
}
if (typeof RemoteAPIs.Driver == "undefined") {
    this.RemoteAPIs.Driver = {}; //Set the global package
}

RemoteAPIs.Driver._handleUnknownAPI = function (remoteAPI) {
    alert("RemoteAPIs.Driver.records_add():> Unknown remote API '"+remoteAPI.api+"'");
}

RemoteAPIs.Driver.records_add = function (remoteAPI, biblio, localrecord, remoterecord, callback) {
    if (remoteAPI.api == "Koha-Suomi") {
        RemoteAPIs.Driver.KohaSuomi.records_add(remoteAPI, biblio, localrecord, remoterecord, callback);
    }
    else {
        RemoteAPIs.Driver._handleUnknownAPI(remoteAPI);
    }
}
RemoteAPIs.Driver.records_check = function (remoteAPI, biblio, recordXml, callback) {
    if (remoteAPI.api == "Koha-Suomi") {
        RemoteAPIs.Driver.KohaSuomi.records_check(remoteAPI, biblio, recordXml, callback);
    }
    else {
        RemoteAPIs.Driver._handleUnknownAPI(remoteAPI);
    }
}
RemoteAPIs.Driver.records_get = function (remoteAPI, biblio, callback) {
    if (remoteAPI.api == "Koha-Suomi") {
        RemoteAPIs.Driver.KohaSuomi.records_get(remoteAPI, biblio, callback);
    }
    else {
        RemoteAPIs.Driver._handleUnknownAPI(remoteAPI);
    }
}
RemoteAPIs.Driver.records_delete = function (remoteAPI, biblionumber, callback) {
    if (remoteAPI.api == "Koha-Suomi") {
        RemoteAPIs.Driver.KohaSuomi.records_delete(remoteAPI, biblionumber, callback);
    }
    else {
        RemoteAPIs.Driver._handleUnknownAPI(remoteAPI);
    }
}

RemoteAPIs.Driver.reports_get = function (remoteAPI, id, callback) {
    if (remoteAPI.api == "Koha-Suomi") {
        RemoteAPIs.Driver.KohaSuomi.reports_get(remoteAPI, id, callback);
    }
    else {
        RemoteAPIs.Driver._handleUnknownAPI(remoteAPI);
    }
}