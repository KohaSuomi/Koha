//package Cataloguing.RecordPusher
if (typeof Cataloguing == "undefined") {
    this.Cataloguing = {}; //Set the global package
}

/**
 *  Cataloguing.RecordPusher enables pushing the given biblio to a user selectable remote repository.
 *  First the recordPusher adds links to the remote repositories to a given container, then listens
 *  for click-events on those links.
 *  When a link is clicked, the recordPusher fetches the complete MARC Record of the given biblio
 *  from the local database and pushes it to the selected remote API.
 *
 *  The remote API should return a list of hateoas links which are used to construct the available
 *  follow-up actions, like DELETE or show the pushed record in the target environment.
 *
 *  Currently authentication to remote APIs is done with the CGISESSID-cookie and if the user wants
 *  to interact with the remote API, they need to log-in to that system first with the same browser.
 *
 *  @param {jQuery selector or element} displayElementContainer, where to display the list of allowed
 *              remote APIs.
 *  @param {String} displayType, Any of:
 *              "dropdown-menu-list" - show remote APIs as <li>-elements in the container.
 *  @param {jQuery selector or element} operationsMenuContainer, where to display the menu of all the
 *              operations that are available on the remote API
 *  @param {Array of RemoteAPI-objects} remoteAPIs, which APIs should be made available to connect to?
 *  @param {Biblio} activeBiblio, which biblio is being pushed?
 */
Cataloguing.RecordPusher = function (
    displayElementContainer,
    displayType,
    operationsMenuContainer,
    remoteAPIs,
    activeBiblio
) {
    var self = this;
    this.displayElementContainer = $(displayElementContainer);
    this.operationsMenuContainer = $(operationsMenuContainer);
    this.displayType = displayType;
    this.remoteAPIs = Cataloguing.RecordPusher.getValidRemoteAPIs(remoteAPIs);
    this.activeBiblio = activeBiblio; //This RecordPusher is bound to this Biblio.
    this.menuActivationClickLocation; //From where was the remote operation triggered, so we can display the operations menu there.
    this.selfAPI = remoteAPIs["self"];
    //Render this object
    var decHtml;
    if (this.displayType == "dropdown-menu-list") {
        decHtml = Cataloguing.RecordPusher.template_dropdownMenuList(this);
    } else {
        alert(
            "Cataloguing.RecordPusher unknown displayType '" +
                this.displayType +
                "'."
        );
    }
    this.displayElementContainer.append(decHtml);
    Cataloguing.RecordPusher.dropdownMenuListBindEvents(this, decHtml);
    //Rendering done!

    this.setOperationsMenuLocation = function (event) {
        self.menuActivationClickLocation = {
            left: event.pageX,
            top: event.pageY,
        };
    };
    this.parseRecord = function (record) {
        return Cataloguing.RecordPusher.parseRecord(record);
    };
    this.castRemoteAPI = function (remoteAPIorId) {
        if (remoteAPIorId instanceof Object) {
            return remoteAPIorId;
        }
        return this.remoteAPIs[remoteAPIorId];
    };
    this.pushToRemote = function (remoteAPIOrId) {
        var remoteAPIPushDestination = this.castRemoteAPI(remoteAPIOrId);
        if (!remoteAPIPushDestination) {
            alert(
                "Cataloguing.RecordPusher.pushToRemote(" +
                    remoteAPIOrId +
                    "):> Unknown remote API id '" +
                    remoteAPIOrId +
                    "' given. Don't know where to push?"
            );
            return;
        }
        // if (! confirm("Are you sure you want to push Record '"+self.activeBiblio.biblionumber+"' to '"+remoteAPIPushDestination.name+"' ?")) {
        //     return;
        // }
        self.displayModal(remoteAPIPushDestination);
    };
    this.getRecord = function (remoteAPIPushDestination) {
        RemoteAPIs.Driver.KohaSuomi.records_get(
            "local",
            self.activeBiblio,
            function (remoteAPI, error, result) {
                if (error) {
                    alert(
                        "Accessing API '" +
                            remoteAPI.name +
                            "' using RemoteAPIs.Driver.records_get() failed with " +
                            error
                    );
                    return;
                }
                RemoteAPIs.Driver.records_check(
                    remoteAPIPushDestination,
                    self.activeBiblio,
                    result,
                    function (remoteAPI, error, result, recordXml) {
                        if (error) {
                            alert(
                                "Accessing API '" +
                                    remoteAPI.name +
                                    "' using RemoteAPIs.Driver.records_check() failed with " +
                                    error
                            );
                            return;
                        }
                        self.displayContent(remoteAPI, result);
                    }
                );
            }
        );
    };
    this.submitToRemote = function (remoteAPIOrId, params) {
        var remoteAPIPushDestination = this.castRemoteAPI(remoteAPIOrId);
        RemoteAPIs.Driver.records_add(
            remoteAPIPushDestination,
            params,
            function (remoteAPI, error, result, recordXml) {
                if (error) {
                    alert(
                        "Accessing API '" +
                            remoteAPI.name +
                            "' using RemoteAPIs.Driver.records_add() failed with " +
                            error
                    );
                    return;
                }
            }
        );
        $("#pushRecordOpModal").find("#report").click();
    };
    this.submitcomponentParts = function (
        remoteAPIOrId,
        componentparts,
        username,
        check
    ) {
        var remoteAPIPushDestination = this.castRemoteAPI(remoteAPIOrId);
        $.each(componentparts, function (index, record) {
            RemoteAPIs.Driver.records_add(
                remoteAPIPushDestination,
                {
                    source_id: record.biblionumber,
                    interface: remoteAPIOrId.interface,
                    marc: record.marcxml,
                    target_id: null,
                    username: username,
                    parent_id: self.activeBiblio.biblionumber,
                    force: 1,
                    check: check,
                },
                undefined,
                function (remoteAPI, error, result, recordXml) {
                    if (error) {
                        alert(
                            "Accessing API '" +
                                remoteAPI.name +
                                "' using RemoteAPIs.Driver.records_add() failed with " +
                                error
                        );
                        return;
                    }
                }
            );
        });
    };
    this.deletecomponentParts = function (componentparts) {
        $.each(componentparts, function (index, record) {
            RemoteAPIs.Driver.KohaSuomi.records_delete(
                "local",
                record.biblionumber,
                function (remoteAPI, error, result) {
                    if (error) {
                        alert(
                            "Cataloguing.RecordPusher.pushToRemote():> Accessing API '" +
                                remoteAPI.name +
                                "' using RemoteAPIs.Driver.KohaSuomi.records_delete() failed with " +
                                error
                        );
                        return;
                    }
                }
            );
        });
    };
    this.getReports = function (remoteAPIOrId, id) {
        var remoteAPIPushDestination = this.castRemoteAPI(remoteAPIOrId);
        RemoteAPIs.Driver.reports_get(
            remoteAPIPushDestination,
            id,
            function (remoteAPI, error, results) {
                if (error) {
                    alert(
                        "Accessing API '" +
                            remoteAPI.name +
                            "' using RemoteAPIs.Driver.reports_get() failed with " +
                            error
                    );
                    return;
                }
                $("#report-wrapper").find(".table-responsive").remove();
                self.showReports(remoteAPI, results);
                $("#pushRecordOpModal")
                    .find("#spinner-wrapper")
                    .addClass("hidden");
            }
        );
    };
    this.deleteFromRemote = function (remoteAPIOrId, biblionumber) {
        var remoteAPI = this.castRemoteAPI(remoteAPIOrId);
        if (!remoteAPI) {
            alert(
                "Cataloguing.RecordPusher.pushToRemote():> Remote API not known. Don't know where to DELETE!"
            );
            return;
        }
        if (
            !confirm(
                "Are you sure you want to DELETE a Record from '" +
                    remoteAPI.name +
                    "' ?"
            )
        ) {
            return;
        }
        RemoteAPIs.Driver.records_delete(
            remoteAPI,
            biblionumber,
            function (remoteAPI, error, result) {
                if (error) {
                    alert(
                        "Cataloguing.RecordPusher.pushToRemote():> Accessing API '" +
                            remoteAPI.name +
                            "' using RemoteAPIs.Driver.KohaSuomi.records_delete() failed with " +
                            error
                    );
                    return;
                }
                //Delete succeeded, hide the Operations menu
                self.operationsMenuContainer
                    .find("#pushRecordOpMenu .circular-menu .circle")
                    .removeClass("open");
                self.operationsMenuContainer
                    .find("#pushRecordOpMenu a")
                    .hide(1000, function () {
                        $(this).parent().remove();
                    });
            }
        );
    };
    this.displayMenu = function (
        remoteAPI,
        biblionumber,
        record,
        hateoasLinks
    ) {
        this.operationsMenuContainer.find("#pushRecordOpMenu").remove();
        var html = $("<div id='pushRecordOpMenu'></div>");

        var nativeViewUrl;
        hateoasLinks.forEach(function (v, i, a) {
            if (v.ref == "self.nativeView") {
                nativeViewUrl = remoteAPI.host + "/" + v.href;
            }
        });
        this.operationsMenuContainer.append(html);
        var radialMenu = new RadialMenu(html, [
            {
                class: "fa fa-trash-o fa-2x",
                title: "DELETE",
                "data-verb": "DELETE",
                events: {
                    click: function (event) {
                        event.preventDefault();
                        self.deleteFromRemote(remoteAPI, biblionumber);
                    },
                },
            },
            {
                class: "fa fa-sign-in fa-2x",
                title: "OPEN IN HOME",
                "data-verb": "GET",
                href: nativeViewUrl,
                target: "_blank",
            },
        ]);
        this.operationsMenuContainer
            .find("#pushRecordOpMenu")
            .css(self.menuActivationClickLocation);
        this.operationsMenuContainer
            .find("#pushRecordOpMenu .menu-button")
            .click(); //Open up the radial menu
    };
    this.displayModal = function (remoteAPI) {
        this.operationsMenuContainer.find("#pushRecordOpModal").remove();
        var html = $(
            '<div id="pushRecordOpModal" class="modal fade" role="dialog">\
                        <div class="modal-dialog">\
                            <div class="modal-content">\
                                <div class="modal-header">\
                                    <ul class="nav nav-pills">\
                                        <li class="nav-item">\
                                            <a id="exporter" class="nav-link" style="background-color:#007bff; color:#fff;" href="#">Siirto<i class="fa fa-refresh" style="margin-left:7px;"></i></a>\
                                        </li>\
                                        <li class="nav-item">\
                                            <a id="report" class="nav-link" href="#">Tapahtumat<i class="hidden fa fa-refresh" style="margin-left:7px;"></i></a>\
                                        </li>\
                                    </ul>\
                                </div>\
                                <div id="spinner-wrapper" class="modal-body row text-center">\
                                    <i class="fa fa-spinner fa-spin" style="font-size:36px"></i>\
                                </div>\
                                <div id="export-wrapper" class="modal-body">\
                                </div>\
                                <div id="report-wrapper" class="modal-body hidden">\
                                </div>\
                                <div class="modal-footer">\
                                    <button id="export" type="button" class="btn btn-success hidden">Vie</button>\
                                    <button id="import" type="button" class="btn btn-primary hidden">Tuo</button>\
                                    <button type="button" class="btn btn-default" data-dismiss="modal">Sulje</button>\
                                </div>\
                            </div>\
                        </div>\
                    </div>'
        );
        this.operationsMenuContainer.append(html);
        $("#pushRecordOpModal").modal("toggle");
        self.getRecord(remoteAPI);
        $("#exporter").click(function (event) {
            event.preventDefault();
            $("#export-wrapper").find("#exportRecord").remove();
            $("#report").removeAttr("style");
            $("#report").find(".fa-refresh").addClass("hidden");
            $(this).find(".fa-refresh").removeClass("hidden");
            $(this).css({ "background-color": "#007bff", color: "#fff" });
            $("#report-wrapper").addClass("hidden");
            $("#export-wrapper").removeClass("hidden");
            $("#spinner-wrapper").removeClass("hidden");
            self.getRecord(remoteAPI);
        });
        $("#report").click(function (event) {
            event.preventDefault();
            $("#spinner-wrapper").removeClass("hidden");
            $("#exporter").removeAttr("style");
            $("#exporter").find(".fa-refresh").addClass("hidden");
            $(this).find(".fa-refresh").removeClass("hidden");
            $(this).css({ "background-color": "#007bff", color: "#fff" });
            $("#export-wrapper").addClass("hidden");
            $("#report-wrapper").removeClass("hidden");
            $("#export").addClass("hidden");
            $("#import").addClass("hidden");
            setTimeout(function () {
                self.getReports(remoteAPI, self.activeBiblio.biblionumber);
            }, 1000);
        });
    };
    this.displayContent = function (remoteAPI, result) {
        $("#spinner-wrapper").addClass("hidden");
        var sourceboxes = false;
        var source = Cataloguing.RecordPusher.parseRecord(
            result.sourcerecord,
            sourceboxes
        );
        var html;
        if (!result.targetrecord && remoteAPI.type == "export") {
            html = $('<div id="exportRecord">' + source + "</div>");
            $("#export").removeClass("hidden");
        } else if (!result.targetrecord && remoteAPI.type == "import") {
            html = $(
                "<div><h2>Tietueen standardinumeroilla ei löytynyt tuloksia.</h2></div>"
            );
        } else {
            var targetboxes = false;
            var target = Cataloguing.RecordPusher.parseRecord(
                result.targetrecord,
                targetboxes
            );
            html = $(
                '<div id="exportRecord"><div class="col-sm-6"><h3>Paikallinen</h4><hr/>' +
                    source +
                    '</div><div class="col-sm-6"><h3>' +
                    result.interface +
                    "</h4><hr/>" +
                    target +
                    "</div></div>"
            );
            if (remoteAPI.type == "export" && !result.source_id) {
                $("#export").removeClass("hidden");
            }
            if (self.selfAPI) {
                $("#import").removeClass("hidden");
            }
            $(".modal-dialog").addClass("modal-lg");
        }
        this.operationsMenuContainer.find("#export-wrapper").append(html);
        self.handleButtons(remoteAPI, result);
    };
    this.handleButtons = function (remoteAPI, result) {
        var username = $(".loggedinusername").html().trim();
        $("#export")
            .unbind()
            .click(function (event) {
                event.preventDefault();
                var count = 0;
                $("input:checkbox[name=record]:not(:checked)").each(
                    function () {
                        if ($(this).val() == "leader") {
                            delete result.sourcerecord[$(this).val()];
                        } else {
                            result.sourcerecord.fields.splice(
                                $(this).val() - count,
                                1
                            );
                            count++;
                        }
                    }
                );
                self.submitToRemote(remoteAPI, {
                    marc: result.sourcerecord,
                    interface: remoteAPI.interface,
                    source_id: self.activeBiblio.biblionumber,
                    target_id: result.target_id,
                    username: username,
                    componentparts_count: result.componentparts.length,
                });
                if (!result.targetrecord) {
                    self.submitcomponentParts(
                        remoteAPI,
                        result.componentparts,
                        username,
                        false
                    );
                } else {
                    self.submitcomponentParts(
                        remoteAPI,
                        result.componentparts,
                        username,
                        true
                    );
                }
            });
        $("#import")
            .unbind()
            .click(function (event) {
                event.preventDefault();
                var sourceid;
                if (result.source_id) {
                    sourceid = result.source_id;
                } else {
                    sourceid = result.target_id;
                }
                if (result.componentparts) {
                    self.deletecomponentParts(result.componentparts);
                }
                self.submitToRemote(self.selfAPI, {
                    marc: result.targetrecord,
                    interface: self.selfAPI.interface,
                    source_id: sourceid,
                    target_id: self.activeBiblio.biblionumber,
                    username: username,
                    componentparts: 1,
                    fetch_interface: remoteAPI.interface,
                });
            });
    };
    this.showReports = function (remoteAPI, result) {
        var html = Cataloguing.RecordPusher.parseReports(
            result,
            self.activeBiblio.biblionumber,
            remoteAPI.interface,
            self.selfAPI.interface
        );
        $("#report-wrapper").append(html);
    };
};

/**
 *  Find the Remote APIs that are capable of doing operations on MARC records.
 *  @param {Array} remoteAPIs
 *  @returns {Array} remoteAPIs that are capable
 */
Cataloguing.RecordPusher.getValidRemoteAPIs = function (remoteAPIs) {
    return remoteAPIs;
};

Cataloguing.RecordPusher.template_dropdownMenuList = function (recordPusher) {
    var remoteAPIs = recordPusher.remoteAPIs;
    if (!remoteAPIs) {
        return "";
    }

    var html =
        '<li class="divider" role="presentation"></li>\n' +
        '<li role="presentation"><a href="#" tabindex="-1" class="menu-inactive" role="menuitem"><strong>Push / Pull:</strong></a></li>\n' +
        '<li class="divider" role="presentation"></li>\n';
    Object.keys(remoteAPIs)
        .sort()
        .forEach(function (v, i, a) {
            var api = remoteAPIs[v];
            if (api.id != "self") {
                html +=
                    '<li><a href="#" id="pushTarget_' +
                    api.id +
                    '">' +
                    api.name +
                    "</a></li>\n";
            }
        });
    return $(html);
};
Cataloguing.RecordPusher.dropdownMenuListBindEvents = function (
    recordPusher,
    displayHtml
) {
    displayHtml.find("[id^='pushTarget_']").click(function (event) {
        recordPusher.setOperationsMenuLocation(event);
        recordPusher.pushToRemote($(this).attr("id").substr(11));
        event.preventDefault();
    });
};
Cataloguing.RecordPusher.parseRecord = function (record, checkbox) {
    var html = "<div>";
    html += '<li class="row"> <div class="col-xs-3">';
    if (checkbox) {
        html += '<input type="checkbox" value="leader" name="record" checked> ';
    }
    html += '<b>000</b></div><div class="col-xs-9">' + record.leader + "</li>";
    record.fields.forEach(function (v, i, a) {
        if ($.isNumeric(v.tag)) {
            html += '<li class="row"><div class="col-xs-3">';
        } else {
            html += '<li class="row hidden"><div class="col-xs-3">';
        }
        if (checkbox) {
            html +=
                '<input type="checkbox" value="' +
                i +
                '" name="record" checked> ';
        }
        html += "<b>" + v.tag;
        if (v.ind1) {
            html += " " + v.ind1;
        }
        if (v.ind2) {
            html += " " + v.ind2;
        }
        html += '</b></div><div class="col-xs-9">';
        if (v.subfields) {
            v.subfields.forEach(function (v, i, a) {
                html += "<b>_" + v.code + "</b>" + v.value + "<br/>";
            });
        } else {
            html += v.value;
        }
        html += "</div></li>";
    });
    html += "</div>";
    return html;
};
Cataloguing.RecordPusher.parseReports = function (
    reports,
    biblionumber,
    interface,
    selfAPI
) {
    var html = '<div class="table-responsive">';
    if (reports.length != 0) {
        html += '<table class="table table-striped table-sm">';
        html +=
            "<thead>\
                <tr>\
                <th>Tapahtuma</th>\
                <th>Aika</th>\
                <th>Tila</th>\
                </tr>\
            </thead><tbody>";
        reports.forEach(function (v, i, a) {
            if (interface == v.interface_name || v.interface_name == selfAPI) {
                html += "<tr>";
                if (v.target_id == biblionumber) {
                    html += '<td style="padding:0 5px;">tuonti (päivitys)</td>';
                } else {
                    if (v.target_id != "" && v.target_id != null) {
                        html +=
                            '<td style="padding:0 5px;">vienti (päivitys)</td>';
                    } else {
                        html += '<td style="padding:0 5px;">vienti (uusi)</td>';
                    }
                }
                html += '<td style="padding:0 5px;">' + v.timestamp + "</td>";
                if (v.status == "success") {
                    html +=
                        '<td style="padding:0 5px; color:green;">onnistui</td>';
                }
                if (v.status == "failed") {
                    html +=
                        '<td style="padding:0 5px; color:red;">epäonnistui (' +
                        v.errorstatus +
                        ")</td>";
                }
                if (v.status == "pending" || v.status == "waiting") {
                    html +=
                        '<td style="padding:0 5px; color:orange;">odottaa</td>';
                }
                html += "</tr>";
            }
        });
        html += "</tbody></table>";
    } else {
        html += "<div><h2>Ei siirtoja</h2></div>";
    }
    html += "</div>";
    return html;
};
