$(document).ready(function() {
  $('#meeting-form').submit(function(e) {
    $(this).find('#selected_meeting_contacts option').each(function(i, v){
      $(v).attr('selected', true);
    });
  });
});
