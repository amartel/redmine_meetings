function SetCheckBoxes(CheckValue, element) {
	if (!document.forms['meeting-form'])
		return;
	var objCheckBoxes = document.forms['meeting-form'].elements[element];
	if (!objCheckBoxes)
		return;
	var countCheckBoxes = objCheckBoxes.length;
	if (!countCheckBoxes)
		objCheckBoxes.checked = CheckValue;
	else
		// set the check value for all check boxes
		for ( var i = 0; i < countCheckBoxes; i++)
			objCheckBoxes[i].checked = CheckValue;
}

function SetAllCheckBoxes(CheckValue) {
  SetCheckBoxes(CheckValue, 'watchers_');
}


function SetAllContactCheckBoxes(CheckValue) {
  SetCheckBoxes(CheckValue, 'contacts_');
}

function sync_date(from, to) {
	document.getElementById(to).value = document.getElementById(from).value;
}

function sync_time(obj, from, to) {
	h_from = document.getElementById(from + "_hour");
	m_from = document.getElementById(from + "_minute");
	h_to = document.getElementById(to + "_hour");
	m_to = document.getElementById(to + "_minute");
	if (h_from.selectedIndex < 23) {
		h_to.selectedIndex = h_from.selectedIndex + 1;
		m_to.selectedIndex = m_from.selectedIndex;
	}
}

function setAutoPreview(url, form, field) {
    new Field.Observer(field,2, function(){
        new Ajax.Updater('preview', url, {
            asynchronous:true,
            evalScripts:true,
            method:'post',
            parameters:Form.serialize(form)
        });
    });
}

function start_meeting(url) {
	var wihe = "width="+screen.availWidth+",height="+screen.availHeight;
	open(url, "Meeting","directories=no,location=no,resizable=yes,scrollbars=yes,status=no,toolbar=no," + wihe);
	return false;
}
