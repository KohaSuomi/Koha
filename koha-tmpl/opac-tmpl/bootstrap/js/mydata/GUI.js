function MyDataView(){
	var self = this;

	self.logs = ko.observableArray();
	self.personal = ko.observableArray();
	self.dataurl = ko.observable(false);
	var json;
	var filename;

	self.JsonData = function(url, name) {
		var dataValues;
		if (name == "logs") {dataValues = {object: borrowernumber};}
		if (name == "personal") {dataValues = {borrowernumber: borrowernumber};}
		$(".spinner-wrapper").removeClass("hidden");
		$.ajax({
	        url: url,
	        type: "GET",
	        data: dataValues,	
	        success: function (data, textStatus, jqXHR) {
	        	if (data) {
		        	if (name == "logs") {self.logs(LogParser(data)); filename = 'logdata_'; json = LogParser(data);}
		        	if (name == "personal") {self.personal(data); filename = 'personaldata_'; json = PersonalParser(data);}
		        	$(".spinner-wrapper").addClass("hidden");
		        	var filedata = "text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(json));
    				$("#loadJSON").attr('href', 'data:' + filedata).attr('download',filename+now+'.json');
		        }
	        },
	        error: function (jqXHR, textStatus, errorThrown) {
	        	$(".spinner-wrapper").addClass("hidden");
	            alert(JSON.stringify(jqXHR.responseJSON));
	        }
	    });
	}

	if (logurl.length > 0) {
		self.dataurl(true);
		self.JsonData(logurl, 'logs');
	}

	self.logData = function(data, event) {
     	$('li').removeClass("active");
     	$(event.target).closest('li').addClass("active");
     	$('#personalList').addClass("hidden");
     	$('#logList').removeClass("hidden");
     	$("#loadJSON").removeAttr("href").removeAttr("download");
     	self.dataurl(false);
     	if (personalurl.length > 0) {
     		self.personal.removeAll();
     	}
     	if (logurl.length > 0) {
			self.dataurl(true);
			self.JsonData(logurl, 'logs');
		}

     }


     self.personalData = function(data, event) {
     	$('li').removeClass("active");
     	$(event.target).closest('li').addClass("active");
     	$('#logList').addClass("hidden");
     	$('#personalList').removeClass("hidden");
     	$("#loadJSON").removeAttr("href").removeAttr("download");
     	self.dataurl(false);
     	if (logurl.length > 0) {
     		self.logs.removeAll();
     	}
     	if (personalurl.length > 0) {
     		self.dataurl(true);
     		self.JsonData(personalurl, 'personal');
     	}
     }

    var userLang = navigator.language || navigator.userLanguage;
	moment.locale(userLang);
	
	var now = moment().format('Y-M-D');

	self.loadPDF = function(data, event) {
		if (self.logs().length > 0) {
			LogPDFTemplate(json, now);
		} 

		if (self.personal().length > 0) {
			PersonalPDFTemplate(json, now);
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
    	var splitInfo = doc.splitTextToSize(json[i].info, 100);
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

function PersonalPDFTemplate(json, time) {
	var translator = new Translator(myDataTranslations);
	var doc = new jsPDF();
    doc.setFontSize(16);
    doc.setLineWidth(100);
    doc.text(translator.translate("My data"), 10, 10);
    doc.text(translator.translate("Personal data"), 10, 20);
    doc.save("personaldata_"+time+".pdf");

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

function PersonalParser(json) {
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