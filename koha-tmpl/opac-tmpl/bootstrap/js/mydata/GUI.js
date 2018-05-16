function MyDataView(){
	var self = this;

	var userLang = navigator.language || navigator.userLanguage;
	moment.locale(userLang);

	var json = JSON.parse(JsonData)
	self.jsonurl = ko.observable(DownloadJSON(json));
	var now = moment().format('Y-M-D');
	self.jsonfile = 'mydata_'+now+'.json';
	self.logs = ko.observableArray(json);

	self.loadPDF = function(data, event) {
        var doc = new jsPDF();
        doc.setFontSize(16);
        doc.text("My Logs", 10, 10);
        doc.text("Timestamp", 10, 20);
        doc.text("Action", 60, 20);
        doc.text("Info", 100, 20);
        doc.setFontSize(10);
        var line = 40;
        for (var i = 0; i < json.length; i++) {
        	doc.text(json[i].timestamp, 10, line);
        	doc.text(json[i].action, 60, line);
        	doc.text(json[i].info, 100, line);
        	line += 20;
        }
        doc.save("plan.pdf");
        /*doc.addHTML(document.body, 0, 0, {width: 800, pagesplit: true}, function () {doc.save("test.pdf")})*/
     }
}

function DownloadJSON(json) {
    var data = "text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(json));
    return 'data:' + data;
}