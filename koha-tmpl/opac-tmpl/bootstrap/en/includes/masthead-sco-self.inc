[% USE Koha %]
[% SET OpacLangSelectorMode = Koha.Preference('OpacLangSelectorMode') %]
<!-- <div id="wrap"> -->
    <div class="navbar navbar-inverse navbar-static-top navbar-black">
        <div class="navbar-inner navbar-black">
            <div class="container-fluid navbar-black">
                <a class="brand" href="/cgi-bin/koha/sco/sco-main.pl"><img src="[% interface %]/[% theme %]/images/koha-logo-navbar.png" alt=""></a>
                <div id="checkouthelp">
                    <ul class="nav pull-right">
                        <li><a href="/cgi-bin/koha/sco/help.pl"><i class="icon help"></i> Help</a></li>
                    </ul>
                </div>

                [% IF ( opaclanguagesdisplay ) %]
                    <div id="members">
                        <ul class="nav pull-right">
                            [% INCLUDE 'masthead-langmenu.inc' %]
                        </ul>
                    </div> <!-- /members -->
                [% END # / IF opaclanguagedisplay %]

            </div> <!-- /container-fluid -->
        </div> <!-- /navbar-inner -->
    </div> <!-- /navbar -->
<!-- </div> -->

    [% IF ( opacheader ) %]
        <div class="container-fluid">
            <div class="row-fluid">
                <div id="opacheader">
                   [% opacheader %]
                </div>
            </div>
        </div>
    [% END %]
