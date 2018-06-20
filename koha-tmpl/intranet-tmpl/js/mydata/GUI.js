$(document).ready(function(){
    $("#printData").click(function(){
		$("#patrondata").find(".buttons").addClass("hidden");
		$("#patrondata").find(".spinner-wrapper").removeClass("hidden");
        var userValues = {borrowernumber: borrowernumber};
		var logValues = {object: borrowernumber};
		if (userUrl) {
			var json = fetchJson(userUrl, userValues);
			if (logUrl) {
				var log = fetchJson(logUrl, logValues);
				json['logs'] = log;
			}
			var userLang = navigator.language || navigator.userLanguage;
			moment.locale(userLang);

			var now = moment().format('Y-M-D');
			PDFTemplate(json, now, "Patron");
			var postValues = {module: "MEMBERS", action: "Print", object: borrowernumber, info: "Printed patron's data"};
			addLogRecord("/api/v1/logs/", postValues);
		} else {
			alert("Missing preferences PersonalInterfaceUrl");
			$("#patrondata").find(".buttons").removeClass("hidden");
			$("#patrondata").find(".spinner-wrapper").addClass("hidden");
		}
    });
});

function MyDataView(){
	var self = this;

	self.logs = ko.observableArray();
	self.user = ko.observableArray();
	self.dataurl = ko.observable(false);
	var json;
	var filename;
	var templatesection;

	var userLang = navigator.language || navigator.userLanguage;
	moment.locale(userLang);

	var now = moment().format('Y-M-D');

	self.JsonData = function(url, name, section) {
		var dataValues;
		if (name == "logs") {dataValues = {object: borrowernumber};}
		if (name == "user") {dataValues = {borrowernumber: borrowernumber, section: section};}
		$(".spinner-wrapper").removeClass("hidden");
		$(".nodata, .dataurl").addClass("hidden");
		var data = fetchJson(url, dataValues);
		if (data) {
			if (name == "logs") {self.logs(dataParser(data)); filename = 'logdata_'; json = data; templatesection = 'logs'}
			if (name == "user") {
				for (var i in data) if (data.hasOwnProperty(i)) {
					self.user(dataParser(data[i]));
					if (section != 'personal') {
						json = data[i];
					}
				}
				filename = section+'data_';
				if (section == 'personal') {
					json = data
				}
				templatesection = section;

			}
			TrimJson(json);
			var filedata = "text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(json));
			$("#loadJSON").attr('href', 'data:' + filedata).attr('download',filename+now+'.json');
		}
		$(".nodata, .dataurl").removeClass("hidden");
		$(".spinner-wrapper").addClass("hidden");
	}

	if (userurl.length > 0) {
		self.dataurl(true);
		self.JsonData(userurl, 'user', 'personal');
	}

	self.logData = function(data, event) {
		$('li').removeClass("active");
		$(event.target).closest('li').addClass("active");
		$('#userList').addClass("hidden");
		$('#logList').removeClass("hidden");
		$("#loadJSON").removeAttr("href").removeAttr("download");
		self.dataurl(false);
		if (userurl.length > 0) {
			self.user.removeAll();
		}
		if (logurl.length > 0) {
			self.dataurl(true);
			self.JsonData(logurl, 'logs');
		}

    }


     self.userData = function(data, event) {
		var section = $(event.currentTarget).attr("section-value");
		$('li').removeClass("active");
		$(event.target).closest('li').addClass("active");
		$('#logList').addClass("hidden");
		$('#userList').removeClass("hidden");
		$("#loadJSON").removeAttr("href").removeAttr("download");
		self.dataurl(false);
		if (logurl.length > 0) {
			self.logs.removeAll();
		}
		if (userurl.length > 0) {
			self.dataurl(true);
			self.JsonData(userurl, 'user', section);
		}
    }

	self.loadPDF = function(data, event) {
		if (self.logs().length > 0) {
			PDFTemplate(json, now, 'log');
		}

		if (self.user().length > 0) {
			PDFTemplate(json, now, templatesection);
		}
		var postValues = {module: "MEMBERS", action: "Print", object: borrowernumber, info: "Printed "+templatesection+" data"};
		addLogRecord("/api/v1/logs/", postValues); 

	}
	self.loadJSON = function(data, event) {
		var postValues = {module: "MEMBERS", action: "Download", object: borrowernumber, info: "Downloaded "+templatesection+" data"};
		addLogRecord("/api/v1/logs/", postValues); 
	}
}

function fetchJson(url, dataValues) {
    var response;
    $.ajax({
        url: url,
        type: "GET",
        data: dataValues,
        cache: true,
        async: false,
        success: function (data, textStatus, jqXHR) {
            response = data;
        },
        error: function (jqXHR, textStatus, errorThrown) {
            alert(JSON.stringify(errorThrown));
        }
    });
    return response;
}

function addLogRecord(url, dataValues) {
    $.ajax({
        url: url,
        type: "POST",
        data: dataValues,
        cache: true,
        async: false,
        success: function (data, textStatus, jqXHR) {
        },
        error: function (jqXHR, textStatus, errorThrown) {
            alert(JSON.stringify(errorThrown));
        }
    });
}

function PDFTemplate(json, time, section) {
	var translator = new Translator(myDataTranslations);
	var doc = new jsPDF();
	var data;
	section = section.substr(0,1).toUpperCase()+section.substr(1);
    doc.setFontSize(16);
    doc.setLineWidth(100);
	doc.text(translator.translate(section), 10, 10);
	doc.text(translator.translate("Field"), 10, 20);
	doc.text(translator.translate("Value"), 60, 20);
	doc.setFontSize(10);
	var line = 30;
	for (var i in json) if (json.hasOwnProperty(i)) {
		data = dataParser(json[i]);
		for (var it = 0; it < data.length; it++) {
			if (data[it].value) {
				doc.text(data[it].key, 10, line);
				var splitValue = "";
				if (data[it].value) {
					splitValue = doc.splitTextToSize(isDate(data[it].value) ? moment(data[it].value).format('lll') : data[it].value, 130);
				}
				doc.text(splitValue, 60, line);
				var lineValue;
				if (splitValue.length >= 2 && splitValue.length < 10) {
					lineValue = 10*splitValue.length-10;
				}else if (splitValue.length >= 10) {
					lineValue = 10*splitValue.length-50;
				} else {
					lineValue = 10;
				}
			}
			line += lineValue;
			if (line >= 250) {
				doc.addPage();
				line = lineValue;
			}
		}
		line += 10;
	}
	doc.save(section+"data_"+time+".pdf");
	$("#patrondata").find(".spinner-wrapper").addClass("hidden");
	$("#patrondata").find(".buttons").removeClass("hidden");

}

function dataParser(json) {
	var self = this;

	self.arr = [];

	for (var i in json) if (json.hasOwnProperty(i)) {
		if ($.isArray(json)) {
			var childJson = json[i];
			for (var it in childJson) if (childJson.hasOwnProperty(it)) {
				if (childJson[it] != "" && childJson[it] != null && childJson[it] != 0 && TrimValues(it)) {
					self.arr.push(parseKeyValue(it, childJson[it]));
				}
			}
			self.arr.push({"row": null});
		} else {
			if (json[i] != "" && json[i] != null && json[i] != 0 && TrimValues(i)) {
				self.arr.push(parseKeyValue(i, json[i]));
			}
		}
	}
	return self.arr;
}

function parseKeyValue(key, value) {

	var hash;
	if (value != "" && value != null && value != 0) {
		hash = {"key": key, "value": TrimInfo(value)};
	}

	return hash
}

function TrimJson(json) {
	var self = this;

	for (var i in json) if (json.hasOwnProperty(i)) {
		if ($.isArray(json)) {
			var childJson = json[i];
			for (var it in childJson) if (childJson.hasOwnProperty(it)) {
				TrimValues(it, childJson);
			}

		} else {
			TrimValues(i, json);
		}
	}

}

function TrimValues(key, array) {
	var arr = ["borrowernumber",
				"issue_id",
				"reserve_id",
				"itemnumber",
				"accountlines_id",
				"manager_id",
				"message_id",
				"biblionumber",
				"borrower_debarment_id",
				"suggestionid",
				"suggestedby",
				"managedby",
				"rejectedby",
				"notify_id",
				"accountno",
				"user",
				"action_id",
				"object"];
	var returnkey = true;

	if ($.inArray( key, arr ) !== -1) {
		if (array) {
			delete array[key]
		} else{
			returnkey = false;
		}

	}

	return returnkey;

}

function TrimInfo(string) {

	if (string.match(/VAR/)) {
		string = string.match(/'action' =>.*'/);
	}

	return string;

}

function Translator(values){
    var self = this;
    self.translations = {};
    self.initTranslations = function(){
        self.translations = values;
    };
    self.isInited = false;

    self.translate = function(string){
        if(!self.isInited){
            self.initTranslations();
            self.isInited = true;
        }
        if(string && self.translations.hasOwnProperty(string)){
            string = self.translations[string];
        }
        return string;
    }
}

function isDate(val) {
    var d = new Date(val);
    return !isNaN(d.valueOf());
}