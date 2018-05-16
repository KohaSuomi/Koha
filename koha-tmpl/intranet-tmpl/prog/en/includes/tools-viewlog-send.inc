<div id="sendModal" class="modal fade" role="dialog">
  <div class="modal-dialog">
    <!-- Modal content-->
    <div class="modal-content">
      <div class="modal-body inputmodal">
        <h3>Send logs to patron</h3>
        <p>Sending patron's whole log history to specified email address</p>
        <span class="missing hidden" style="color:red;">Email is missing!</span>
        <span class="validate hidden" style="color:red;">Not valid email!</span>
        <form id="sendForm" action="/cgi-bin/koha/tools/viewlog.pl" method="post">
          <div class="form-group">
            <label for="sendEmail">Email address</label>
            <input type="text" class="form-control" id="sendemail" name="email" value="[% email | html %]">
            <input type="hidden" class="form-control" name="object" value="[% object %]">
            <input type="hidden" class="form-control" name="do_it" value="1" />
          </div>
        </form>
      </div>
      <div class="modal-body confirmmodal hidden">
        <p>Are you sure?</p>
      </div>
      <div class="modal-footer">
        <button type="button" form="sendForm" id="sendToEmail" class="btn btn-primary"><i class="fa fa-envelope" aria-hidden="true"></i> Send</button>
        <button type="button" form="sendForm" id="confirmEmail" class="btn btn-success hidden" data-dismiss="modal"><i class="fa fa-envelope" aria-hidden="true"></i> Confirm</button>
        <button type="button" id="dismissModal" class="btn btn-default" data-dismiss="modal">Close</button>
      </div>
    </div>
    <script>
      $( "#sendToEmail" ).click(function() {
        var email = $("#sendemail").val();
        if( !email ) {
          $(".validate").addClass('hidden');
          $(".missing").removeClass('hidden');
        } else if (!validateEmail(email))  {
          $(".missing").addClass('hidden');
          $(".validate").removeClass('hidden');
        } else {
          $("#sendemail").val();
          $(".inputmodal").hide();
          $(this).hide();
          $(".confirmmodal").removeClass("hidden");
          $("#confirmEmail").removeClass("hidden");
        }
      });
      $( "#confirmEmail" ).click(function() {
        $( "#sendForm" ).submit();
      });
      function validateEmail($email) {
        var emailReg = /^([\w-\.]+@([\w-]+\.)+[\w-]{2,4})?$/;
        return emailReg.test( $email );
      }
    </script>
  </div>
</div>