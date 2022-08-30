function display_pickup_location (state) {
    var $text;
    if ( state.needs_override === true ) {
        $text = $(
            '<span>' + state.text + '</span> <span style="float:right;" title="' +
            __("This pickup location is not allowed according to circulation rules") +
            '"><i class="fa fa-exclamation-circle" aria-hidden="true"></i></span>'
        );
    }
    else {
        $text = $('<span>'+state.text+'</span>');
    }

    return $text;
};

(function ($) {

    /**
     * Generate a Select2 dropdown for pickup locations
     *
     * It expects the select object to contain several data-* attributes
     * - data-pickup-location-source: 'biblio', 'item' or 'hold' (default)
     * - data-patron-id: required for 'biblio' and 'item'
     * - data-biblio-id: required for 'biblio' only
     * - data-item-id: required for 'item' only
     *
     * @return {Object} The Select2 instance
     */

    $.fn.pickup_locations_dropdown = function () {
        var select = $(this);
        var pickup_location_source = $(this).data('pickup-location-source');
        var patron_id = $(this).data('patron-id');
        var biblio_id = $(this).data('biblio-id');
        var item_id = $(this).data('item-id');
        var hold_id = $(this).data('hold-id');

        var url;

        if ( pickup_location_source === 'biblio' ) {
            url = '/api/v1/biblios/' + encodeURIComponent(biblio_id) + '/pickup_locations';
        }
        else if ( pickup_location_source === 'item' ) {
            url = '/api/v1/items/' + encodeURIComponent(item_id) + '/pickup_locations';
        }
        else { // hold
            url = '/api/v1/holds/' + encodeURIComponent(hold_id) + '/pickup_locations';
        }

        select.select2({
            width: 'style',
            allowClear: false,
            ajax: {
                url: url,
                delay: 300, // wait 300 milliseconds before triggering the request
                cache: true,
                dataType: 'json',
                data: function (params) {
                    var search_term = (params.term === undefined) ? '' : params.term;
                    var query = {
                        "q": JSON.stringify({"name":{"-like":'%'+search_term+'%'}}),
                        "_order_by": "name",
                        "_page": params.page
                    };

                    if ( pickup_location_source !== 'hold' ) {
                        query["patron_id"] = patron_id;
                    }

                    return query;
                },
                processResults: function (data) {
                    var results = [];
                    data.results.forEach( function ( pickup_location ) {
                        results.push(
                            {
                                "id": pickup_location.library_id.escapeHtml(),
                                "text": pickup_location.name.escapeHtml(),
                                "needs_override": pickup_location.needs_override
                            }
                        );
                    });
                    return { "results": results, "pagination": { "more": data.pagination.more } };
                },
                transport: kohaSelect2Transport,
            },
            templateResult: display_pickup_location
        });

        return select;
    };
})(jQuery);

/* global __ dataTablesDefaults borrowernumber SuspendHoldsIntranet */
$(document).ready(function() {
    var holdsTable;

    // Don't load holds table unless it is clicked on
    $("#holds-tab").on( "click", function(){ load_holds_table() } );

    // If the holds tab is preselected on load, we need to load the table
    if ( $("#holds-tab").parent().hasClass('ui-state-active') ) { load_holds_table() }

    function load_holds_table() {
        var holds = new Array();
        if ( ! holdsTable ) {
            var title;
            holdsTable = $("#holds-table").dataTable($.extend(true, {}, dataTablesDefaults, {
                "bAutoWidth": false,
                "sDom": "rt",
                "columns": [
                    {
                        "data": { _: "reservedate_formatted", "sort": "reservedate" }
                    },
                    {
                        "mDataProp": function ( oObj ) {
                            title = "<a href='/cgi-bin/koha/reserve/request.pl?biblionumber="
                                  + oObj.biblionumber
                                  + "'>"
                                  + oObj.title.escapeHtml();

                            $.each(oObj.subtitle, function( index, value ) {
                                title += " " + value.escapeHtml();
                            });

                            title += " " + oObj.part_number + " " + oObj.part_name;

                            if ( oObj.enumchron ) {
                                title += " (" + oObj.enumchron.escapeHtml() + ")";
                            }

                            title += "</a>";

                            if ( oObj.author ) {
                                title += " " + __("by _AUTHOR_").replace("_AUTHOR_", oObj.author.escapeHtml());
                            }

                            if ( oObj.itemnotes ) {
                                var span_class = "";
                                if ( flatpickr.formatDate( new Date(oObj.issuedate), "Y-m-d" ) == ymd ){
                                    span_class = "circ-hlt";
                                }
                                title += " - <span class='" + span_class + "'>" + oObj.itemnotes.escapeHtml() + "</span>"
                            }

                            return title;
                        }
                    },
                    {
                        "mDataProp": function( oObj ) {
                            return oObj.itemcallnumber && oObj.itemcallnumber.escapeHtml() || "";
                        }
                    },
                    {
                        "mDataProp": function( oObj ) {
                            var data = "";
                            if ( oObj.barcode ) {
                                data += " <a href='/cgi-bin/koha/catalogue/moredetail.pl?biblionumber="
                                  + oObj.biblionumber
                                  + "&itemnumber="
                                  + oObj.itemnumber
                                  + "#item"
                                  + oObj.itemnumber
                                  + "'>"
                                  + oObj.barcode.escapeHtml()
                                  + "</a>";
                            }
                            return data;
                        }
                    },
                    {
                        "mDataProp": function( oObj ) {
                            if( oObj.branches.length > 1 && oObj.found !== 'W' && oObj.found !== 'T' ){
                                var branchSelect='<select priority='+oObj.priority+' class="hold_location_select" data-hold-id="'+oObj.reserve_id+'" reserve_id="'+oObj.reserve_id+'" name="pick-location" data-pickup-location-source="hold">';
                                for ( var i=0; i < oObj.branches.length; i++ ){
                                    var selectedbranch;
                                    var setbranch;
                                    if( oObj.branches[i].selected ){

                                        selectedbranch = " selected='selected' ";
                                        setbranch = __(" (current) ");
                                    } else if ( oObj.branches[i].pickup_location == 0 ) {
                                        continue;
                                    } else{
                                        selectedbranch = '';
                                        setbranch = '';
                                    }
                                    branchSelect += '<option value="'+ oObj.branches[i].branchcode.escapeHtml() +'"'+selectedbranch+'>'+oObj.branches[i].branchname.escapeHtml()+setbranch+'</option>';
                                }
                                branchSelect +='</select>';
                                return branchSelect;
                            }
                            else { return oObj.branchcode.escapeHtml() || ""; }
                        }
                    },
                    { "data": { _: "expirationdate_formatted", "sort": "expirationdate" } },
                    {
                        "mDataProp": function( oObj ) {
                            if ( oObj.priority && parseInt( oObj.priority ) && parseInt( oObj.priority ) > 0 ) {
                                return oObj.priority;
                            } else {
                                return "";
                            }
                        }
                    },
                    {
                        "bSortable": false,
                        "mDataProp": function( oObj ) {
                            return "<select name='rank-request'>"
                                 +"<option value='n'>" + __("No") + "</option>"
                                 +"<option value='del'>" + __("Yes") + "</option>"
                                 + "</select>"
                                 + "<input type='hidden' name='biblionumber' value='" + oObj.biblionumber + "'>"
                                 + "<input type='hidden' name='borrowernumber' value='" + borrowernumber + "'>"
                                 + "<input type='hidden' name='reserve_id' value='" + oObj.reserve_id + "'>";
                        }
                    },
                    {
                        "bSortable": false,
                        "visible": SuspendHoldsIntranet,
                        "mDataProp": function( oObj ) {
                            holds[oObj.reserve_id] = oObj; //Store holds for later use

                            if ( oObj.found ) {
                                return "";
                            } else if ( oObj.suspend == 1 ) {
                                return "<a class='hold-resume btn btn-default btn-xs' id='resume" + oObj.reserve_id + "'>"
                                     +"<i class='fa fa-play'></i> " + __("Resume") + "</a>";
                            } else {
                                return "<a class='hold-suspend btn btn-default btn-xs' id='suspend" + oObj.reserve_id + "'>"
                                     +"<i class='fa fa-pause'></i> " + __("Suspend") + "</a>";
                            }
                        }
                    },
                    {
                        "mDataProp": function( oObj ) {
                            var data = "";

                            if ( oObj.suspend == 1 ) {
                                data += "<p>" + __("Hold is <strong>suspended</strong>");
                                if ( oObj.suspend_until ) {
                                    data += " " + __("until %s").format(oObj.suspend_until_formatted);
                                }
                                data += "</p>";
                            }

                            if ( oObj.itemtype_limit ) {
                                data += __("Next available %s item").format(oObj.itemtype_limit);
                            }

                            if ( oObj.barcode ) {
                                data += "<em>";
                                if ( oObj.found == "W" ) {

                                    if ( oObj.waiting_here ) {
                                        data += __("Item is <strong>waiting here</strong>");
                                        if (oObj.desk_name) {
                                            data += ", " + __("at %s").format(oObj.desk_name.escapeHtml());
                                        }
                                    } else {
                                        data += __("Item is <strong>waiting</strong>");
                                        data += " " + __("at %s").format(oObj.waiting_at);
                                        if (oObj.desk_name) {
                                            data += ", " + __("at %s").format(oObj.desk_name.escapeHtml());
                                        }

                                    }

                                } else if ( oObj.transferred ) {
                                    data += __("Item is <strong>in transit</strong> from %s since %s").format(oObj.from_branch, oObj.date_sent);
                                } else if ( oObj.not_transferred ) {
                                    data += __("Item hasn't been transferred yet from %s").format(oObj.not_transferred_by);
                                }
                                data += "</em>";
                            }
                            return data;
                        }
                    }
                ],
                "bPaginate": false,
                "bProcessing": true,
                "bServerSide": false,
                "ajax": {
                    "url": '/cgi-bin/koha/svc/holds',
                    "data": function ( d ) {
                        d.borrowernumber = borrowernumber;
                    }
                },
            }));

            $('#holds-table').on( 'draw.dt', function () {
                $(".hold-suspend").on( "click", function() {
                    var id = $(this).attr("id").replace("suspend", "");
                    var hold = holds[id];
                    $("#suspend-modal-title").html( hold.title );
                    $("#suspend-modal-reserve_id").val( hold.reserve_id );
                    $('#suspend-modal').modal('show');
                });

                $(".hold-resume").on( "click", function() {
                    var id = $(this).attr("id").replace("resume", "");
                    var hold = holds[id];
                    $.post('/cgi-bin/koha/svc/hold/resume', { "reserve_id": hold.reserve_id }, function( data ){
                      if ( data.success ) {
                          holdsTable.api().ajax.reload();
                      } else {
                        if ( data.error == "HOLD_NOT_FOUND" ) {
                            alert( __("Unable to resume, hold not found") );
                            holdsTable.api().ajax.reload();
                        }
                      }
                    });
                });

                $(".hold_location_select").each(function(){ $(this).pickup_locations_dropdown(); });

                $(".hold_location_select").on("change", function(){
                    $(this).prop("disabled",true);
                    var cur_select = $(this);
                    var res_id = $(this).attr('reserve_id');
                    $(this).after('<div id="updating_reserveno'+res_id+'" class="waiting"><img src="/intranet-tmpl/prog/img/spinner-small.gif" alt="" /><span class="waiting_msg"></span></div>');
                    var api_url = '/api/v1/holds/' + encodeURIComponent(res_id) + '/pickup_location';
                    $.ajax({
                        method: "PUT",
                        url: api_url,
                        data: JSON.stringify({ "pickup_library_id": $(this).val() }),
                        headers: { "x-koha-override": "any" },
                        success: function( data ){ holdsTable.api().ajax.reload(); },
                        error: function( jqXHR, textStatus, errorThrown) {
                            alert('There was an error:'+textStatus+" "+errorThrown);
                            cur_select.prop("disabled",false);
                            $("#updating_reserveno"+res_id).remove();
                            cur_select.val( cur_select.children('option[selected="selected"]').val() );
                        },
                    });
                });

            });

            if ( $("#holds-table").length ) {
                $("#holds-table_processing").position({
                    of: $( "#holds-table" ),
                    collision: "none"
                });
            }
        }
    }

    $("body").append("\
        <div id='suspend-modal' class='modal fade' role='dialog' aria-hidden='true'>\
            <div class='modal-dialog'>\
            <div class='modal-content'>\
            <form id='suspend-modal-form' class='form-inline'>\
                <div class='modal-header'>\
                    <button type='button' class='closebtn' data-dismiss='modal' aria-hidden='true'>×</button>\
                    <h3 id='suspend-modal-label'>" + __("Suspend hold on") + " <i><span id='suspend-modal-title'></span></i></h3>\
                </div>\
\
                <div class='modal-body'>\
                    <input type='hidden' id='suspend-modal-reserve_id' name='reserve_id' />\
\
                    <label for='suspend-modal-until'>" + __("Suspend until:") + "</label>\
                    <input name='suspend_until' id='suspend-modal-until' class='suspend-until flatpickr' data-flatpickr-futuredate='true' size='10' />\
\
                    <p><a class='btn btn-link' id='suspend-modal-clear-date' >" + __("Clear date to suspend indefinitely") + "</a></p>\
\
                </div>\
\
                <div class='modal-footer'>\
                    <button id='suspend-modal-submit' class='btn btn-primary' type='submit' name='submit'>" + __("Suspend") + "</button>\
                    <a href='#' data-dismiss='modal' aria-hidden='true' class='cancel'>" + __("Cancel") + "</a>\
                </div>\
            </form>\
            </div>\
            </div>\
        </div>\
    ");

    $("#suspend-modal-clear-date").on( "click", function() { $("#suspend-modal-until").val(""); } );

    $("#suspend-modal-submit").on( "click", function( e ) {
        e.preventDefault();
        $.post('/cgi-bin/koha/svc/hold/suspend', $('#suspend-modal-form').serialize(), function( data ){
          $('#suspend-modal').modal('hide');
          if ( data.success ) {
              holdsTable.api().ajax.reload();
          } else {
            if ( data.error == "INVALID_DATE" ) {
                alert( __("Unable to suspend hold, invalid date") );
            }
            else if ( data.error == "HOLD_NOT_FOUND" ) {
                alert( __("Unable to suspend hold, hold not found") );
                holdsTable.api().ajax.reload();
            }
          }
        });
    });

    $(".toggle-suspend").on('click', function(e) {
        e.preventDefault();
        let reserve_id     = $(this).data('reserve-id');
        let biblionumber   = $(this).data('biblionumber');
        let suspend_until  = $('#suspend_until_' + reserve_id).val();
        window.location.href='request.pl?action=toggleSuspend&amp;reserve_id=' + reserve_id + '&amp;biblionumber=' + biblionumber + '&amp;suspend_until=' + suspend_until;
        return false;
    });
});

function fetch_libraries() {
    return $.ajax({
        method: "GET",
        url: "/api/v1/libraries",
        data: {_per_page: -1},
        success: function(data, textStatus, request){
        },
        error: function( jqXHR, textStatus, errorThrown) {
            console.log(errorThrown);
        },
    });
}

async function load_holds_queue() {
    let totalHolds;
    const dataJson = {
        currentPage: 0 // added by me to easily manage correct page displaying
    }
    const multiChange = {};
    const libraries = await fetch_libraries();
    var holdsQueueTable = $("#holds-queue").DataTable($.extend(true, {}, dataTablesDefaults,{
        "ajax": async function (d, callback, s) {
            const info = $('#holds-queue').DataTable().page.info();
            $.ajax({
                method: "GET",
                url: "/api/v1/holds/?biblio_id="+biblionumber,
                data: {_page: info.page+1, _per_page: info.length, _order_by: 'priority', _match: 'exact'},
                success: function(data, textStatus, request){
                    totalHolds = request.getResponseHeader('X-Total-Count');
                    totalHoldsSelect = parseInt(totalHolds)+1;
                    dataJson.recordsTotal = totalHolds;
                    dataJson.recordsFiltered = totalHolds;
                    dataJson.data = data;
                    callback(
                        dataJson
                    )
                },
                error: function( jqXHR, textStatus, errorThrown) {
                    console.log(errorThrown);
                },
            });
        },
        "bProcessing": true,
        "ordering": false,
        searching: false,
        displayStart: dataJson.currentPage*20,
        serverSide: true,
        columnDefs: [
            {
                targets: [2, 3],
                className: 'dt-body-nowrap'
            },
            {
                targets: [2, 9],
                visible: CAN_user_reserveforothers_modify_holds_priority ? true : false
            },

        ],
        columns: [
            {"mDataProp": function( data ) {return '<input type="checkbox" class="select_hold" data-hold-id="'+data.hold_id+'"/>'}},
            {"mDataProp": function( data ) {
                    if(CAN_user_reserveforothers_modify_holds_priority) {
                        let select = '<select name="rank-request" class="rank-request" data-hold-id="'+data.hold_id;
                        for ( var i=0; i < totalHoldsSelect; i++ ){
                            let selected;
                            let value;
                            let desc;
                            if (data.priority == i && data.status == 'T') {
                                select += '" disabled="disabled">';
                                selected = " selected='selected' ";
                                value = 'T';
                                desc = 'In transit';
                            } else if (data.priority == i && data.status == 'P') {
                                select += '" disabled="disabled">';
                                selected = " selected='selected' ";
                                value = 'P';
                                desc = 'In processing';
                            } else if (data.priority == i && data.status == 'W'){
                                select += '" disabled="disabled">';
                                selected = " selected='selected' ";
                                value = 'W';
                                desc = 'Waiting';
                            } else if (data.priority == i && !data.status) {
                                select += '">';
                                selected = " selected='selected' ";
                                value = data.priority;
                                desc = data.priority;
                            } else {
                                if (i != 0) {
                                    select += '">';
                                    value = i;
                                    desc = i;
                                } else {
                                    select += '">';
                                }
                            }
                            if (value) {
                                select += '<option value="'+ value +'"'+selected+'>'+desc+'</option>';
                            }
                        }
                        select += '</select>';
                        return select;
                    }else {
                        return data.priority;
                    }
                }
            },
            {
                "mDataProp": function (data) {
                    if (data.status) {
                        return null;
                    }
                    let buttons = '<a title="Move hold up" href="#" class="move-hold" data-move-hold="up" data-priority="'+data.priority+'" reserve_id="'+data.hold_id+'"><img src="/intranet-tmpl/prog/img/go-up.png" alt="Go up" /></a>';
                    buttons += '<a title="Move hold to top" href="#" class="move-hold" data-move-hold="top" data-priority="'+data.priority+'" reserve_id="'+data.hold_id+'"><img src="/intranet-tmpl/prog/img/go-top.png" alt="Go top" /></a>';
                    buttons += '<a title="Move hold to bottom" href="#" class="move-hold" data-move-hold="bottom" data-priority="'+data.priority+'" reserve_id="'+data.hold_id+'"><img src="/intranet-tmpl/prog/img/go-bottom.png" alt="Go bottom" /></a>';
                    buttons += '<a title="Move hold down" href="#" class="move-hold" data-move-hold="down" data-priority="'+data.priority+'" reserve_id="'+data.hold_id+'"><img src="/intranet-tmpl/prog/img/go-down.png" alt="Go down" /></a>';
                    return buttons;
                }
            },
            { 
                "mDataProp": function( data, type, full, meta) {
                    let currentCell = $("#holds-queue").DataTable().cells({"row":meta.row, "column":meta.col}).nodes(0);
                    $.ajax({
                        method: "GET",
                        url: "/api/v1/patrons/"+data.patron_id,
                        success: function(res){
                            patron = HidePatronName ? res.cardnumber : res.firstname+' '+ res.surname+' ('+res.cardnumber+')';
                            $(currentCell).html('<a href="/cgi-bin/koha/members/moremember.pl?borrowernumber='+data.patron_id+'">'+patron+'</a>');
                        }
                    });
                    return '<img src="/intranet-tmpl/prog/img/spinner-small.gif" alt="" /><span class="waiting_msg"></span></div>';
                }
            },
            {data: "notes"},
            {
                "mDataProp": function(data) {
                    if (AllowHoldDateInFuture) {
                        return '<input type="text" class="holddate" value="'+$date(data.hold_date)+'" size="10" name="hold_date" data-hold-id="'+data.hold_id+'" data-current-date="'+data.hold_date+'"/>';
                    } else {
                        return $date(data.hold_date);
                    }
                }
            },
            {
                "mDataProp": function(data) {
                    return '<input type="text" class="expirationdate" value="'+$date(data.expiration_date)+'" size="10" name="expiration_date" data-hold-id="'+data.hold_id+'" data-current-date="'+data.expiration_date+'"/>';
                }
            },
            {
                "mDataProp": function( data, type, full, meta ) {
                    var branchSelect='<select priority='+data.priority+' class="hold_location_select" data-hold-id="'+data.hold_id+'" reserve_id="'+data.hold_id+'" name="pick-location" data-pickup-location-source="hold">';
                    var libraryname;
                    for ( var i=0; i < libraries.length; i++ ){
                        var selectedbranch;
                        var setbranch;
                        if( libraries[i].library_id == data.pickup_library_id ){

                            selectedbranch = " selected='selected' ";
                            setbranch = __(" (current) ");
                            libraryname = libraries[i].name;
                        } else if ( libraries[i].pickup_location == false ) {
                            continue;
                        } else{
                            selectedbranch = '';
                            setbranch = '';
                        }
                        branchSelect += '<option value="'+ libraries[i].library_id.escapeHtml() +'"'+selectedbranch+'>'+libraries[i].name.escapeHtml()+setbranch+'</option>';
                    }
                    branchSelect +='</select>';
                    
                    if ( data.status == 'T' ) {
                        return __("Item being transferred to <strong>%s</strong>").format(libraryname);
                    } else if (data.status == 'P') {
                        return __("Item being processed at <strong>%s</strong>").format(libraryname);
                    } else if (data.status == 'W') {
                        return __("Item waiting at <strong>%s</strong> since %s").format(libraryname, $date(data.waiting_date));   
                    } else {
                        return branchSelect;
                    }
                    
                }
            },
            { 
                "mDataProp": function( data, type, full, meta) {
                    if (data.item_id) {
                        let currentCell = $("#holds-queue").DataTable().cells({"row":meta.row, "column":meta.col}).nodes(0);
                        $.ajax({
                            method: "GET",
                            url: "/api/v1/items/"+data.item_id,
                            success: function(res){
                                $(currentCell).html('<a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber='+biblionumber+'&itemnumber='+data.item_id+'">'+res.external_id+'</a>');
                            }
                        });
                        return '<img src="/intranet-tmpl/prog/img/spinner-small.gif" alt="" /><span class="waiting_msg"></span></div>';
                    } else {
                        if (data.non_priority) {
                            return '<em>'+__("Next available")+'</em><br/><i>'+__("Non priority hold")+'</i>';
                        } else {
                            return '<em>'+__("Next available")+'</em>';
                        }
                    }
                }
            },
            { 
                "mDataProp": function( data, type, full, meta) {
                    let link = 'request.pl?action=setLowestPriority&amp;borrowernumber='+data.patron_id+'&amp;biblionumber='+data.biblio_id+'&amp;reserve_id='+data.hold_id+'&amp;date='+data.hold_date+'';
                    if (data.lowest_priority) {
                        return '<a href="'+link+'" class="unset-lowest-priority"><img src="/intranet-tmpl/prog/img/go-bottom.png" alt="Unset lowest priority" /></a>';
                    } else if (data.item_id) {
                        return null
                    } else {
                        return '<a href="'+link+'" class="set-lowest-priority"><img src="/intranet-tmpl/prog/img/go-down.png" alt="Set to lowest priority" /></a>';
                    }
                }
            },
            { 
                "mDataProp": function( data, type, full, meta) {
                    return '<a class="btn btn-default btn-xs cancel-hold" reserve_id="'+data.hold_id+'"><i class="fa fa-trash" aria-hidden="true"></i> '+__("Cancel")+'</a>';
                }
            },
            { 
                "mDataProp": function( data, type, full, meta) {
                    if ( data.status == 'T' ) {
                        return '<input type="button" value="'+__("Revert transit status")+'" onclick="window.location.href=\'request.pl?action=move&amp;where=down&amp;first_priority=1&amp;last_priority='+totalHolds+'&amp;prev_priority=0&amp;next_priority=1&amp;borrowernumber='+data.patron_id+'&amp;biblionumber='+data.biblio_id+'&amp;itemnumber='+data.item_id+'&amp;reserve_id='+data.hold_id+'&amp;date='+data.hold_date+'\'">';
                    } else if (data.status == 'W' || data.status == 'P') {
                        return '<input type="button" value="'+__("Revert waiting status")+'" onclick="window.location.href=\'request.pl?action=move&amp;where=down&amp;first_priority=1&amp;last_priority='+totalHolds+'&amp;prev_priority=0&amp;next_priority=1&amp;borrowernumber='+data.patron_id+'&amp;biblionumber='+data.biblio_id+'&amp;itemnumber='+data.item_id+'&amp;reserve_id='+data.hold_id+'&amp;date='+data.hold_date+'\'">';  
                    } else {
                        var td = '';
                        if (SuspendHoldsIntranet) {
                            td += '<button class="btn btn-default btn-xs toggle-suspend" data-hold-id="'+data.hold_id+'" data-biblionumber="'+data.biblio_id+'" data-suspended="'+data.suspended+'">'
                            if ( data.suspended ) {
                                td += '<i class="fa fa-play" aria-hidden="true"></i> '+__("Resume")+'</button>';
                            } else {
                                td += '<i class="fa fa-pause" aria-hidden="true"></i> '+__("Suspend")+'</button>';
                            }
                            if (AutoResumeSuspendedHolds) {
                                if (data.suspended) {
                                    td += '<label for="suspend_until_'+data.hold_id+'">'+__("Suspend on")+' </label>';
                                } else {
                                    td += '<label for="suspend_until_'+data.hold_id+'">'+__("Suspend until")+' </label>';
                                }
                                td += '<input type="text" name="suspend_until_'+data.hold_id+'" data-hold-id="'+data.hold_id+'" size="10" value="'+$date(data.suspended_until)+'" class="suspenddate" data-flatpickr-futuredate="true" data-current-date="'+data.suspended_until+'" />';
                            }
                            return td;
                        } else {
                            return null;
                        }
                    }
                }
            },
            { 
                "mDataProp": function( data, type, full, meta) {
                    return '<input class="printholdslip" type="button" name="printholdslip" value="'+__("Print slip")+'" data-reserve_id="'+data.hold_id+'">';
                }
            },
        ]
    }));
    $('#holds-queue').on( 'draw.dt', function () {
        let multiselect = false;
        $(".select_hold").on("click",function(e) {
            $(this).parent().parent().toggleClass('selected');
            $("#cancellation-reason-fieldset").show();
            multiselect = true;
        });
        $(".cancel-hold").on("click",function(e) {
            e.preventDefault;
            var res_id = $(this).attr('reserve_id');
            $('#cancelModal').modal('show').find('#cancelModalConfirmBtnAPI').attr("data-hold-id", res_id);
        });
        $("#cancelModalConfirmBtnAPI").one("click",function(e) {
            e.preventDefault();
            var hold_id = $(this).attr('data-hold-id');
            let reason = $("#modal-cancellation-reason").val();
            if (!multiselect) {
                $.ajax({
                    method: "DELETE",
                    url: '/api/v1/holds/' + encodeURIComponent(hold_id),
                    data: JSON.stringify(reason),
                    success: function( data ){ $('#cancelModal').modal("hide"); holdsQueueTable.ajax.reload(null, false); },
                    error: function( jqXHR, textStatus, errorThrown) {
                        //alert('There was an error:'+textStatus+" "+errorThrown);
                    },
                });
            }
        });
        $(".holddate, .expirationdate").flatpickr({
            dateFormat: flatpickr_dateformat_string,
            onChange: function (selectedDates, dateStr, instance){
                let hold_id = $(instance.input).attr('data-hold-id');
                let fieldname = $(instance.input).attr('name');
                let current_date = $(instance.input).attr('data-current-date');
                const date = new Date(selectedDates);
                const year = date.getFullYear();
                const month = String(date.getMonth() + 1).padStart(2, '0');
                const day = String(date.getDate()).padStart(2, '0');
                let newdate;
                if (year && month && day) {
                    newdate = [year, month, day].join('-');
                }
                multiChange[hold_id] = fieldname == "hold_date" ? {"hold_date": newdate} : { "expiration_date": dateStr };
                let req = fieldname == "hold_date" ? { "hold_date": newdate } : { "expiration_date": newdate };
                if (current_date != newdate && !multiselect) {
                    $.ajax({
                        method: "PUT",
                        url: '/api/v1/holds/' + encodeURIComponent(hold_id) +'/'+fieldname,
                        data: JSON.stringify(req),
                        success: function( data ){ holdsQueueTable.ajax.reload(null, false); },
                        error: function( jqXHR, textStatus, errorThrown) {
                            holdsQueueTable.ajax.reload(null, false);
                        },
                    });
                }
            }
        });
        $(".suspenddate").flatpickr({
            dateFormat: flatpickr_dateformat_string,
            onChange: function (selectedDates, dateStr, instance){
                let hold_id = $(instance.input).attr('data-hold-id');
                let current_date = $(instance.input).attr('data-current-date');
                const date = new Date(selectedDates);
                const year = date.getFullYear();
                const month = String(date.getMonth() + 1).padStart(2, '0');
                const day = String(date.getDate()).padStart(2, '0');
                const newdate = [year, month, day].join('-');
                const method = dateStr ? 'POST' : 'DELETE';
                multiChange[hold_id] = {suspended_until: dateStr};
                if (current_date != newdate && !multiselect) {
                    $.ajax({
                        method: method,
                        url: '/api/v1/holds/' + encodeURIComponent(hold_id) +'/suspension',
                        data: JSON.stringify({ "end_date": newdate }),
                        success: function( data ){ holdsQueueTable.ajax.reload(null, false); },
                        error: function( jqXHR, textStatus, errorThrown) {
                            holdsQueueTable.ajax.reload(null, false);
                        },
                    });
                }
            }
        });
        $(".toggle-suspend").one("click",function(e) {
            e.preventDefault();
            const hold_id = $(this).data('hold-id');
            const suspended = $(this).attr('data-suspended');
            const method = suspended == 'true' ? 'DELETE' : 'POST';
            if (!multiselect) {
                $.ajax({
                    method: method,
                    url: '/api/v1/holds/' + encodeURIComponent(hold_id) +'/suspension',
                    success: function( data ){ holdsQueueTable.ajax.reload(null, false); },
                    error: function( jqXHR, textStatus, errorThrown) {
                        holdsQueueTable.ajax.reload(null, false);
                        alert('There was an error:'+textStatus+" "+errorThrown);
                    },
                });
            }
        });
        $(".rank-request").on("change", function(e){
            e.preventDefault();
            const hold_id = $(this).data('hold-id');
            let priority = e.target.value;
            multiChange[hold_id] = {priority: priority};
            if (!multiselect) {
                $.ajax({
                    method: "PUT",
                    url: '/api/v1/holds/' + encodeURIComponent(hold_id) +'/priority',
                    data: JSON.stringify(priority),
                    success: function( data ){ holdsQueueTable.ajax.reload(null, false); },
                    error: function( jqXHR, textStatus, errorThrown) {
                        alert('There was an error:'+textStatus+" "+errorThrown);
                    },
                });
            }
        }); 
        $(".move-hold").one("click", function(e){
            e.preventDefault();
            let toPosition = $(this).attr('data-move-hold');
            let priority = $(this).attr('data-priority');
            var res_id = $(this).attr('reserve_id');
            var moveTo;
            if (toPosition == 'up'){
                moveTo = parseInt(priority)-1;
            }
            if (toPosition == 'down'){
                moveTo = parseInt(priority)+1;
            }
            if (toPosition == 'top'){
                moveTo = 1;
            }
            if (toPosition == 'bottom'){
                moveTo = totalHolds;
            }
            if (!multiselect) {
                $.ajax({
                    method: "PUT",
                    url: '/api/v1/holds/' + encodeURIComponent(res_id) +'/priority',
                    data: JSON.stringify(moveTo),
                    success: function( data ){ holdsQueueTable.ajax.reload(null, false); },
                    error: function( jqXHR, textStatus, errorThrown) {
                        alert('There was an error:'+textStatus+" "+errorThrown);
                    },
                });
            }
        }); 
        $(".hold_location_select").on("change", function(){
            $(this).prop("disabled",true);
            var cur_select = $(this);
            var res_id = $(this).attr('reserve_id');
            multiChange[res_id] = {pickup_library_id: $(this).val()};
            if (!multiselect) {
                $(this).after('<div id="updating_reserveno'+res_id+'" class="waiting"><img src="/intranet-tmpl/prog/img/spinner-small.gif" alt="" /><span class="waiting_msg"></span></div>');
                let api_url = '/api/v1/holds/' + encodeURIComponent(res_id) + '/pickup_location';
                $.ajax({
                    method: "PUT",
                    url: api_url,
                    data: JSON.stringify({ "pickup_library_id": $(this).val() }),
                    headers: { "x-koha-override": "any" },
                    success: function( data ){ holdsQueueTable.ajax.reload(null, false); },
                    error: function( jqXHR, textStatus, errorThrown) {
                        alert('There was an error:'+textStatus+" "+errorThrown);
                        cur_select.prop("disabled",false);
                        $("#updating_reserveno"+res_id).remove();
                        cur_select.val( cur_select.children('option[selected="selected"]').val() );
                    },
                });
            }
        });
        $('.printholdslip').one('click', function(){
            var reserve_id = $(this).attr('data-reserve_id');
            window.open("/cgi-bin/koha/circ/hold-transfer-slip.pl?reserve_id=" + reserve_id);
            return false;
        });
    });
    $('.update_selected_holds').on('click', function () {
        const data = []
        holdsQueueTable.rows('.selected').every(function (index, element) {
            data.push(this.data());
        });
        fieldNames = {
            hold_id: 'reserve_id',                 
            hold_date: 'reservedate',
            pickup_library_id: 'pickup',
            item_id: 'itemnumber',
            expiration_date: 'expirationdate',
            suspended_until: 'suspend_until',
            priority: 'rank-request',
        };
        let formData = new FormData();
        data.forEach((row) => {
            Object.keys(row).forEach((key) => {
                let update = multiChange[row.hold_id];
                if (update && update[key]) {
                    row[key] = update[key];
                }
                if (fieldNames[key] && row[key] != null) {
                    formData.append(fieldNames[key], row[key])
                }
            });
        });
        
        $.ajax({
            url         : '/cgi-bin/koha/reserve/modrequest.pl',
            data        : formData,
            processData : false,
            contentType : false,
            type: 'POST'
        }).done(function(data){
            holdsQueueTable.ajax.reload(null, false);
        });
    });
    $('.cancel_selected').on('click', function () {
        const data = []
        holdsQueueTable.rows('.selected').every(function (index, element) {
            data.push(this.data());
        });
        const idsArray = [];
        let biblio_id;
        data.forEach((row) => {
            biblio_id = row.biblio_id;
            idsArray.push(row.hold_id);
        });

        let link = '/cgi-bin/koha/reserve/request.pl?biblionumber='+biblio_id+'&amp;action=cancelBulk&amp;ids='+idsArray;
        let reason = $("#cancellation-reason").val();
        if ( reason ) {
            link += "&amp;cancellation-reason=" + reason
        }

        $.ajax({
            url         : link,
            processData : false,
            contentType : false,
            type: 'GET'
        }).done(function(data){
            holdsQueueTable.ajax.reload(null, false);
        });
    });
}