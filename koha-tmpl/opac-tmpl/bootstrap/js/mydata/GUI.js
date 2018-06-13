function MyDataView(){
	var self = this;

	self.logs = ko.observableArray();
	self.user = ko.observableArray();
	self.dataurl = ko.observable(false);
	var json;
	var filename;
	var templatesection;

	self.JsonData = function(url, name, section) {
		var dataValues;
		if (name == "logs") {dataValues = {object: borrowernumber};}
		if (name == "user") {dataValues = {borrowernumber: borrowernumber, section: section};}
		$(".spinner-wrapper").removeClass("hidden");
		$.ajax({
	        url: url,
	        type: "GET",
	        data: dataValues,	
	        success: function (data, textStatus, jqXHR) {
	        	if (data) {
		        	if (name == "logs") {self.logs(LogParser(data)); filename = 'logdata_'; json = LogParser(data);}
		        	if (name == "user") {
						for (var i in data) if (data.hasOwnProperty(i)) {
							self.user(userParser(data[i]));
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
					$(".spinner-wrapper").addClass("hidden");
					TrimJson(json);
		        	var filedata = "text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(json));
    				$("#loadJSON").attr('href', 'data:' + filedata).attr('download',filename+now+'.json');
		        }
	        },
	        error: function (jqXHR, textStatus, errorThrown) {
	        	$(".spinner-wrapper").addClass("hidden");
	            alert(JSON.stringify(jqXHR.statusText));
	        }
	    });
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

    var userLang = navigator.language || navigator.userLanguage;
	moment.locale(userLang);
	
	var now = moment().format('Y-M-D');

	self.loadPDF = function(data, event) {
		if (self.logs().length > 0) {
			LogPDFTemplate(json, now);
		} 

		if (self.user().length > 0) {
			userPDFTemplate(json, now, templatesection);
		} 
		
    }
}


function LogPDFTemplate(json, time) {
	var translator = new Translator(myDataTranslations);
	var doc = new jsPDF();
    doc.setFontSize(16);
    doc.setLineWidth(100);
    doc.text(translator.translate("My data"), 10, 10);
    doc.text(translator.translate("Timestamp"), 10, 20);
    doc.text(translator.translate("Action"), 60, 20);
    doc.text(translator.translate("Info"), 100, 20);
    doc.setFontSize(10);
    var line = 40;
    for (var i = 0; i < json.length; i++) {
    	doc.text(moment(json[i].timestamp).format('lll'), 10, line);
		doc.text(json[i].action, 60, line);
		var splitInfo = "";
		if (json[i].info) {
			splitInfo = doc.splitTextToSize(json[i].info, 100);
		}
    	doc.text(splitInfo, 100, line);
    	var lineValue;
    	if (splitInfo.length > 3 && splitInfo.length <= 9) {
    		lineValue = 40;
    	} else if (splitInfo.length > 9) {
    		lineValue = 60;
    	} else {
    		lineValue = 20;
    	}
    	line += lineValue;
    	if (line >= 250) {
    		doc.addPage();
    		line = lineValue;
    	}
    }
    doc.save("logdata_"+time+".pdf");

}

function userPDFTemplate(json, time, section) {
	var translator = new Translator(myDataTranslations);
	var doc = new jsPDF();
	var data;
	section = section.substr(0,1).toUpperCase()+section.substr(1);
    doc.setFontSize(16);
    doc.setLineWidth(100);
	doc.text(translator.translate(section), 10, 10);
	doc.text(translator.translate("Key"), 10, 20);
	doc.text(translator.translate("Value"), 60, 20);
	doc.setFontSize(10);
	var line = 30;
	for (var i in json) if (json.hasOwnProperty(i)) {
		data = userParser(json[i]);
		var lineValue = 10;
		for (var it = 0; it < data.length; it++) {
			if (data[it].value) {
				doc.text(data[it].key, 10, line);
				doc.text(isDate(data[it].value) ? moment(data[it].value).format('lll') : data[it].value, 60, line);
			}
			line += lineValue;
			if (line >= 290) {
				doc.addPage();
				line = lineValue;
			}
		}
	}
	doc.save(section+"data_"+time+".pdf");

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

function LogParser(json) {
	var self = this;

	self.arr = [];

	for (var i = 0; i < json.length; i++) {
		self.arr.push({
            timestamp: json[i].timestamp, 
            action:  json[i].action,
            info: TrimInfo(json[i].info)
        });
	}
	return self.arr;
}

function TrimInfo(string) {

	if (string.match(/VAR/)) {
		string = string.match(/'action' =>.*'/);
	}
	
	return string;

}

function userParser(json) {
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
		hash = {"key": key, "value": value}; 
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
				"rejectedby"];
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

function isDate(val) {
    var d = new Date(val);
    return !isNaN(d.valueOf());
}