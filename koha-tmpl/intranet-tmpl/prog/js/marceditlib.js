if ( KOHA === undefined ) var KOHA = {};

/*
  - Get and set field value:
    var f = KOHA.MarcEdit.GetField('003');
    f.value = 'FOO:' + f.value;

  - Get and set subfield value:
    var f = KOHA.MarcEdit.GetField('020q');
    f.value = 'FOO:' + f.value;

  - A (sub)field not in the editor returns undefined.
  - A subfield with empty value returns undefined.

  - Get and set indicators:
    var f = KOHA.MarcEdit.GetField('020');
    alert(f.ind(1));
    f.ind(2,'9');

  - If you want to access more than the first of repeated fields,
    use GetFieldRaw()

  - Click on the Tag Editor of a field:
    var f = KOHA.MarcEdit.GetFieldExist('006');
    f.tageditor();

*/

KOHA.MarcEdit = {
    GetItemFieldValue: function (fieldnum, subfield) {
        if (fieldnum.length == 4 && subfield === undefined) {
            subfield = fieldnum.substr(-1, 1);
            fieldnum = fieldnum.slice(0, -1);
        }
	var data = $("select[id^='tag_"+fieldnum+"_subfield_"+subfield+"']").val() ||
	    $("input[id^='tag_"+fieldnum+"_subfield_"+subfield+"']").val() ||
	    $("div[id^='subfield"+subfield+"']").find("select").val();
        console.log(data);
	return data;
    },
    GetFieldRaw: function (fieldnum) {
        console.log("getfieldraw called");
        console.log("fieldnum");
        console.log(fieldnum);
        var ret = [ ];
        $("input[id^='tag_"+fieldnum+"_']").each(function () {
            console.log("foreach");
            var field = {
                tag: fieldnum,
                get value() {
                    return (this._elem !== undefined) ? $(this._elem).val() : undefined;
                },
                set value(v) {
                    if (this._elem !== undefined)
                        $(this._elem).val(v);
                },
                ind: function(ind,val) {
                    var i = parseInt(ind);
                    if (i < 1 || i > 2) return;
                    i--;
                    if (this._ind_elem[i] === undefined) return;
                    if (val === undefined) return $(this._ind_elem[i]).val();
                    if (val.length != 1) return;
                    $(this._ind_elem[i]).val(val);
                }
            };
            if (parseInt(fieldnum) >= 10) {
                field._ind_elem = [
                    $( this ).find("input[name^='tag_"+fieldnum+"_indicator1_']"),
                    $( this ).find("input[name^='tag_"+fieldnum+"_indicator2_']")
                ];
            }
            $("input[id^='tag_"+fieldnum+"_subfield_']").each(function () {
                var id = $( this ).attr('id');
                console.log("ids inside getfieldraw");
                console.log(id);
                if (parseInt(fieldnum) < 10) {
                    field._elem = this;
		    field.tageditor = function() {
			var id = $(this._elem).attr('id');
			$("a[id='buttonDot_"+id+"']").click();
		    }
                } else {
                    var re = /^tag_..._subfield_(.)_/;
                    var found = id.match(re);
                    var subf = {
                        tag: fieldnum,
                        code: found[1],
                        _elem: this,
                        get value() { return $(this._elem).val(); },
                        set value(v) { $(this._elem).val(v); },
                        ind: field.ind,
                        _ind_elem: field._ind_elem,
			tageditor: function() {
			    var id = $(this._elem).attr('id');
			    $("a[id='buttonDot_"+id+"']").click();
			}
                    };
                    field.subfields = field.subfields || [ ];
                    field.subfields.push(subf);
                }
            });
            ret.push(field);
        });
        return ret;
    },
    /* Return a single (sub)field */
    GetFieldExist: function (fieldnum, subfield) {
        console.log(fieldnum);
        console.log(subfield);
        if (fieldnum.length == 4 && subfield === undefined) {
            subfield = fieldnum.substr(-1, 1);
            fieldnum = fieldnum.slice(0, -1);
        }
        var fields = this.GetFieldRaw(fieldnum);
        console.log("getfieldexist fields length:");
        console.log(fields.length);
        if (fields.length < 1) return undefined;
        var f = fields[0];
        console.log("f before if");
        console.log(f);
        if ((parseInt(f.tag) < 10) || subfield === undefined || subfield.length !== 1) return f;
        var v = f.subfields.filter(temp => temp.code == subfield);
        if (v.length < 1) return undefined;
        return v[0];
    },
    /* Return a single (sub)field, undefined if value is empty.
       We cannot distinguish between empty value and nonexistent field. */
    GetField: function (fieldnum, subfield) {
        console.log("Called GetField");
	var f = this.GetFieldExist(fieldnum, subfield);
        if (f.value === '') return undefined;
        return f;
    },
    GetTitle: function () {
        return this.GetField('100a') || this.GetField('110a') || this.GetField('111a') || this.GetField('130a') || this.GetField('245a');
    }
};
