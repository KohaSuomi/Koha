$(document).ready(function(){
    $("#printData").click(function(){
		$("#patrondata").find(".buttons").addClass("hidden");
		$("#patrondata").find(".spinner-wrapper").removeClass("hidden");
        var userValues = {borrowernumber: borrowernumber};
		var logValues = {object: borrowernumber};
		var callback = function(json, textStatus, errorThrown) {
			if(textStatus == "error") {
				alert(JSON.stringify(errorThrown));
				$("#patrondata").find(".buttons").removeClass("hidden");
				$("#patrondata").find(".spinner-wrapper").addClass("hidden");
			} else {
				if (userUrl) {
					if (logUrl) {
						var logcallback = function(log, textStatus) {
							if(textStatus != "error") {
								json['logs'] = log
							}
							printPDF(json);
						}
						fetchJson(logUrl, logValues, logcallback);
					} else {
						printPDF(json);
					}
				} else {
					alert("Missing preferences PersonalInterfaceUrl");
					$("#patrondata").find(".buttons").removeClass("hidden");
					$("#patrondata").find(".spinner-wrapper").addClass("hidden");
				}
			}
        };
		fetchJson(userUrl, userValues, callback);
    });
});

function printPDF (json) {
	var userLang = navigator.language || navigator.userLanguage;
	moment.locale(userLang);

	var now = moment().format('Y-M-D');
	PDFTemplate(json, now, "Patron");
	var postValues = {module: "MEMBERS", action: "Print", object: borrowernumber, info: "Printed patron's data"};
	addLogRecord("/api/v1/logs/", postValues);
}

function MyDataView(){
	var self = this;

	self.user = ko.observableArray();
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
		var callback = function(data, textStatus, errorThrown) {
			if(textStatus == "error" || data.length === 0) {
				if(textStatus == "error"){alert(JSON.stringify(errorThrown))};
				$(".nodata").removeClass("hidden");
				$("#mydata").find(".spinner-wrapper").addClass("hidden");
			} else {
				if (section == "logs") {
					self.user(dataParser(data));
				} else {
					for (var i in data) if (data.hasOwnProperty(i)) {
						self.user(dataParser(data[i]));
						if (section != 'personal') {
							json = data[i];
						}
					}
				}
				filename = section+'data_';
				if (section == 'personal' || section == 'logs') {
					json = data
				}
				templatesection = section;
				TrimJson(json);
				var filedata = "text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(json));
				$("#loadJSON").attr('href', 'data:' + filedata).attr('download',filename+now+'.json');
				$("#mydata").find(".spinner-wrapper").addClass("hidden");
				$('.'+section).removeClass("hidden");
			}
		}
		fetchJson(url, dataValues, callback);
	}

	if (userurl.length > 0) {
		self.JsonData(userurl, 'user', 'personal');
	} else {
		$(".nodata").removeClass("hidden");
		$("#mydata").find(".spinner-wrapper").addClass("hidden");
	}

     self.userData = function(data, event) {
		var section = $(event.currentTarget).attr("section-value");
		activateLoading(event, section);
		if (section == 'logs' && logurl.length > 0) {
			self.JsonData(logurl, 'logs', section);
		} else if (section != 'logs' && userurl.length > 0) {
			self.JsonData(userurl, 'user', section);
		} else {
			$(".nodata").removeClass("hidden");
			$("#mydata").find(".spinner-wrapper").addClass("hidden");
		}
    }

	self.loadPDF = function(data, event) {
		if (self.user().length > 0) {
			PDFTemplate(json, now, templatesection);
		}
		$("#mydata").find(".spinner-wrapper").removeClass("hidden");
		var postValues = {module: "MEMBERS", action: "Print", object: borrowernumber, info: "Printed "+templatesection+" data"};
		addLogRecord("/api/v1/logs/", postValues);

	}
	self.loadJSON = function(data, event) {
		$("#mydata").find(".spinner-wrapper").removeClass("hidden");
		var postValues = {module: "MEMBERS", action: "Download", object: borrowernumber, info: "Downloaded "+templatesection+" data"};
		addLogRecord("/api/v1/logs/", postValues);
	}
}

function fetchJson(url, dataValues, callback) {
    $.ajax({
        url: url,
        type: "GET",
        data: dataValues,
        cache: true,
        async: true
    }).done(function (data, textStatus, jqXHR) {
		if (callback) callback(data, textStatus, jqXHR);
	}).fail(function(jqXHR, textStatus, errorThrown) {
		if (callback) callback(jqXHR, textStatus, errorThrown);
	});
}

function activateLoading(event, section) {

	$('li').removeClass("active");
	$(event.target).closest('li').addClass("active");
	$("#mydata").find(".spinner-wrapper").removeClass("hidden");
	$(".nodata").addClass("hidden");
	$('#userList').removeClass();
	$("#userList").addClass("hidden");
	$("#userList").addClass(section);
	$("#loadJSON").removeAttr("href").removeAttr("download");
}

function addLogRecord(url, dataValues) {
    $.ajax({
        url: url,
        type: "POST",
		data: dataValues,
		cache: true,
        async: true
    }).done(function (data, textStatus, jqXHR) {
		$("#mydata").find(".spinner-wrapper").addClass("hidden");
		$("#patrondata").find(".spinner-wrapper").addClass("hidden");
		$("#patrondata").find(".buttons").removeClass("hidden");
	}).fail(function(jqXHR, textStatus, errorThrown) {
		alert(JSON.stringify(errorThrown));
	});
}

function getDataInfo(url) {
	var response;
    $.ajax({
        url: url,
        type: "GET",
        cache: true,
        async: false
	}).done(function (data, textStatus, jqXHR) {
		response = data;
	}).fail(function() {
		response = null;
	});
	return response;
}

function PDFTemplate(json, time, section) {
	var translator = new Translator(myDataTranslations);
	var doc = new jsPDF();
	var data;
	section = section.substr(0,1).toUpperCase()+section.substr(1);
    doc.setFontSize(10);
    doc.setLineWidth(100);
	doc.text(translator.translate(section), 10, 10);
	doc.text(translator.translate("Field"), 10, 20);
	doc.text(translator.translate("Value"), 50, 20);
	doc.setFontSize(9);
	var line = 30;
	for (var i in json) if (json.hasOwnProperty(i)) {
		data = dataParser(json[i]);
		for (var it = 0; it < data.length; it++) {
			if (data[it] && data[it].value) {
				doc.text(data[it].key, 10, line);
				var splitValue = "";
				if (data[it].value) {
					splitValue = doc.splitTextToSize(data[it].value, 145);
				}
				doc.text(splitValue, 50, line);
				var lineValue;
				if (splitValue.length >= 2) {
					lineValue = 9*splitValue.length/2;
				} else {
					lineValue = 9;
				}
			}
			line += lineValue;
			if (line >= 250) {
				doc.addPage();
				line = lineValue;
			}
		}
		line += 9;
	}
	doc.save(section+"data_"+time+".pdf");

}

function dataParser(json) {
	var self = this;

	self.arr = [];

	for (var i in json) if (json.hasOwnProperty(i)) {
		if ($.isArray(json)) {
			var childJson = json[i];
			for (var it in childJson) if (childJson.hasOwnProperty(it)) {
				if (childJson[it] != "" && childJson[it] != null && childJson[it] != 0 && TrimValues(it)) {
					if (it == "itemnumber") {
						var item = getDataInfo('/api/v1/items/'+childJson[it]);
						if (item) {
							it = "barcode", 
							childJson[it] = item.barcode ? item.barcode : "No barcode";
						}
					}
					if (it == "biblionumber") {
						var biblio = getDataInfo('/api/v1/biblios/'+childJson[it]);
						if (biblio) {
							it = "title", 
							childJson[it] = biblio.title ? biblio.title : "No title";
						}
					}
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
				TrimValues(it, childJson, ["biblionumber", "itemnumber"]);
			}

		} else {
			TrimValues(i, json, ["biblionumber", "itemnumber"]);
		}
	}

}

function TrimValues(key, array, addisonalValues) {
	var arr = ["borrowernumber",
				"issue_id",
				"reserve_id",
				"accountlines_id",
				"manager_id",
				"message_id",
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
	arr = arr.concat(addisonalValues);
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