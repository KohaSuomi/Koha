<?xml version='1.0'?>
<!DOCTYPE stylesheet [<!ENTITY nbsp "&#160;" >]>
<xsl:stylesheet version="1.0" xmlns:marc="http://www.loc.gov/MARC21/slim" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" exclude-result-prefixes="marc">
  <xsl:include href="MARC21Languages.xsl"/>
	<xsl:template name="datafield">
		<xsl:param name="tag"/>
		<xsl:param name="ind1"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="ind2"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="subfields"/>
		<xsl:element name="datafield">
			<xsl:attribute name="tag">
				<xsl:value-of select="$tag"/>
			</xsl:attribute>
			<xsl:attribute name="ind1">
				<xsl:value-of select="$ind1"/>
			</xsl:attribute>
			<xsl:attribute name="ind2">
				<xsl:value-of select="$ind2"/>
			</xsl:attribute>
			<xsl:copy-of select="$subfields"/>
		</xsl:element>
	</xsl:template>

	<xsl:template name="subfieldSelect">
		<xsl:param name="codes"/>
		<xsl:param name="delimeter"><xsl:text> </xsl:text></xsl:param>
		<xsl:param name="subdivCodes"/>
		<xsl:param name="subdivDelimiter"/>
        <xsl:param name="prefix"/>
        <xsl:param name="suffix"/>
		<xsl:variable name="str">
			<xsl:for-each select="marc:subfield">
				<xsl:if test="contains($codes, @code)">
                    <xsl:if test="contains($subdivCodes, @code)">
                        <xsl:value-of select="$subdivDelimiter"/>
                    </xsl:if>
					<xsl:value-of select="$prefix"/><xsl:value-of select="text()"/><xsl:value-of select="$suffix"/><xsl:value-of select="$delimeter"/>
				</xsl:if>
			</xsl:for-each>
		</xsl:variable>
		<xsl:value-of select="substring($str,1,string-length($str)-string-length($delimeter))"/>
	</xsl:template>

    <xsl:template name="subfieldSelectSpan">
        <xsl:param name="codes"/>
        <xsl:param name="delimeter"><xsl:text> </xsl:text></xsl:param>
        <xsl:param name="subdivCodes"/>
        <xsl:param name="subdivDelimiter"/>
        <xsl:param name="prefix"/>
        <xsl:param name="suffix"/>
            <xsl:for-each select="marc:subfield">
                <xsl:if test="contains($codes, @code)">
                    <span>
                        <xsl:attribute name="class"><xsl:value-of select="@code"/></xsl:attribute>
                        <xsl:if test="contains($subdivCodes, @code)">
                            <xsl:value-of select="$subdivDelimiter"/>
                        </xsl:if>
                        <xsl:value-of select="$prefix"/><xsl:value-of select="text()"/><xsl:value-of select="$suffix"/><xsl:if test="position()!=last()"><xsl:value-of select="$delimeter"/></xsl:if>
                    </span>
                </xsl:if>
            </xsl:for-each>
    </xsl:template>

	<xsl:template name="buildSpaces">
		<xsl:param name="spaces"/>
		<xsl:param name="char"><xsl:text> </xsl:text></xsl:param>
		<xsl:if test="$spaces>0">
			<xsl:value-of select="$char"/>
			<xsl:call-template name="buildSpaces">
				<xsl:with-param name="spaces" select="$spaces - 1"/>
				<xsl:with-param name="char" select="$char"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>

    <xsl:template name="buildBiblioDefaultViewURL">
        <xsl:param name="IntranetBiblioDefaultView"/>
        <xsl:choose>
            <xsl:when test="$IntranetBiblioDefaultView='normal'">
                <xsl:text>/cgi-bin/koha/catalogue/detail.pl?biblionumber=</xsl:text>
            </xsl:when>
            <xsl:when test="$IntranetBiblioDefaultView='isbd'">
                <xsl:text>/cgi-bin/koha/catalogue/ISBDdetail.pl?biblionumber=</xsl:text>
            </xsl:when>
            <xsl:when test="$IntranetBiblioDefaultView='labeled_marc'">
                <xsl:text>/cgi-bin/koha/catalogue/labeledMARCdetail.pl?biblionumber=</xsl:text>
            </xsl:when>
            <xsl:when test="$IntranetBiblioDefaultView='marc'">
                <xsl:text>/cgi-bin/koha/catalogue/MARCdetail.pl?biblionumber=</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>/cgi-bin/koha/catalogue/detail.pl?biblionumber=</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

	<xsl:template name="chopPunctuation">
		<xsl:param name="chopString"/>
		<xsl:variable name="length" select="string-length($chopString)"/>
		<xsl:choose>
			<xsl:when test="$length=0"/>
			<xsl:when test="contains('.:,;/ ', substring($chopString,$length,1))">
				<xsl:call-template name="chopPunctuation">
					<xsl:with-param name="chopString" select="substring($chopString,1,$length - 1)"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:when test="not($chopString)"/>
			<xsl:otherwise><xsl:value-of select="$chopString"/></xsl:otherwise>
		</xsl:choose>
	</xsl:template>

	<!-- Function extractControlNumber is used to extract the control number (record number) from MARC tags 773/80/85 [etc.] subfield $w.
	     Parameter: control number string.
	     Assumes LOC convention: (OrgCode)recordNumber.
	     If OrgCode is not present, return full string.
	     Additionally, handle various brackets/parentheses. Chop leading and trailing spaces.
	-->
	<xsl:template name="extractControlNumber">
	    <xsl:param name="subfieldW"/>
	    <xsl:variable name="tranW" select="translate($subfieldW,']})&gt;','))))')"/>
	    <xsl:choose>
	      <xsl:when test="contains($tranW,')')">
	        <xsl:value-of select="normalize-space(translate(substring-after($tranW,')'),'[]{}()&lt;&gt;',''))"/>
	      </xsl:when>
	      <xsl:otherwise>
	        <xsl:value-of select="normalize-space($subfieldW)"/>
	      </xsl:otherwise>
	    </xsl:choose>
	</xsl:template>

	<!-- Function extractControlNumberIdentifier is used to extract the control number identifier from MARC tags 773/80/85 [etc.] subfield $w.
	     Parameter: control number string.
	     Assumes LOC convention: (OrgCode)recordNumber.
	     If OrgCode is not present, return empty string.
	     Additionally, handle various brackets/parentheses. Chop leading and trailing spaces.
	-->
	<xsl:template name="extractControlNumberIdentifier">
	    <xsl:param name="subfieldW"/>
	    <xsl:variable name="tranW" select="translate($subfieldW,']})&gt;','))))')"/>
	    <xsl:choose>
	      <xsl:when test="contains($tranW,'(') and contains($tranW,')')">
	        <xsl:value-of select="normalize-space(translate(substring-before(substring-after($tranW,'('), ')'),'[]{}()&lt;&gt;',''))"/>
	      </xsl:when>
	      <xsl:otherwise>
	      </xsl:otherwise>
	    </xsl:choose>
	</xsl:template>

    <!-- Function m880Select:  Display Alternate Graphic Representation (MARC 880) for selected latin "base"tags
        - should be called immediately before the corresonding latin tags are processed 
        - tags in right-to-left languages are displayed floating right
        * Parameter:
           + basetags: display these tags if found in linkage section ( subfield 6) of tag 880
           + codes: display these subfields codes
        * Options: 
            - class: wrap output in <span class="$class">...</span>
            - label: prefix each(!) tag with label $label
            - bibno: link to biblionumber $bibno
            - index: build a search link using index $index with subfield $a as key; if subfield $9 is present use index 'an' with key $9 instead.
         * Limitations:
            - displays every field on a separate line (to switch between rtl and ltr)
         * Pitfalls:
           (!) output might be empty
    --> 
    <xsl:template name="m880Select">
         <xsl:param name="basetags"/> <!-- e.g.  100,700,110,710 -->
        <xsl:param name="codes"/> <!-- e.g. abc  -->
        <xsl:param name="class"/> <!-- e.g. results_summary -->
        <xsl:param name="label"/> <!-- e.g.  Edition -->
        <xsl:param name="bibno"/>
        <xsl:param name="index"/> <!-- e.g.  au -->
        <xsl:param name="UseAuthoritiesForTracings"/>

        <xsl:for-each select="marc:datafield[@tag=880]">
            <xsl:variable name="code6" select="marc:subfield[@code=6]"/>
            <xsl:if test="contains(string($basetags), substring($code6,1,3))">
                <span>
                    <xsl:choose>
                    <xsl:when test="boolean($class) and substring($code6,string-length($code6)-1,2) ='/r'">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/> m880</xsl:attribute>
                        <xsl:attribute name="dir">rtl</xsl:attribute>
                    </xsl:when>
                     <xsl:when test="boolean($class)">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/></xsl:attribute>
                        <xsl:attribute name="style">display:block; </xsl:attribute>
                    </xsl:when>    
                     <xsl:when test="substring($code6,string-length($code6)-1,2) ='/r'">
                        <xsl:attribute name="class"><xsl:value-of select="$class"/> m880</xsl:attribute>
                    </xsl:when>                                    
                    </xsl:choose>
                    <xsl:if test="boolean($label)">
                        <span class="label">
                            <xsl:value-of select="$label"/>
                        </span>
                    </xsl:if>
                    <xsl:variable name="str">
                        <xsl:for-each select="marc:subfield">
                            <xsl:if test="contains($codes, @code)">
                                <xsl:value-of select="text()"/>
                                <xsl:text> </xsl:text>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:choose>
                        <xsl:when test="boolean($bibno)">
                            <a>
                                <xsl:attribute name="href">/cgi-bin/koha/catalogue/detail.pl?biblionumber=<xsl:value-of  select="$bibno"/></xsl:attribute>
                                <xsl:value-of select="$str"/>
                            </a>
                        </xsl:when>
                       <xsl:when test="boolean($index) and boolean(marc:subfield[@code=9]) and $UseAuthoritiesForTracings='1'">
                            <a>
                                <xsl:attribute name="href">/cgi-bin/koha/catalogue/search.pl?q=an:<xsl:value-of  select="marc:subfield[@code=9]"/></xsl:attribute>
                                  <xsl:value-of select="$str"/>
                            </a>
                        </xsl:when>
                        <xsl:when test="boolean($index)">
                            <a>
                                <xsl:attribute name="href">/cgi-bin/koha/catalogue/search.pl?q=<xsl:value-of  select="$index"/>:<xsl:value-of  select="marc:subfield[@code='a']"/></xsl:attribute>
                                <xsl:value-of select="$str"/>
                            </a>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$str"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </span>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template name="showRDAtag264">
    <!-- Function showRDAtag264 shows selected information from tag 264
         on the Publisher line (used by OPAC Detail and Results)
         Depending on how many tags you have, we will pick by preference
         Publisher-latest or Publisher or 'Other'-latest or 'Other'
         The preferred tag is saved in the fav variable and passed to a
         helper named-template -->
    <!-- Amended  to show all 264 fields (filtered by ind1=3 if ind1=3 is present in the record)  -->
        <xsl:param name="show_url"/>
        <xsl:choose>
            <xsl:when test="marc:datafield[@tag=264 and @ind1=3]">
                <xsl:for-each select="marc:datafield[@tag=264 and @ind1=3]">
                    <xsl:call-template name="showRDAtag264helper">
                        <xsl:with-param name="field" select="."/>
                        <xsl:with-param name="url" select="$show_url"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="marc:datafield[@tag=264]">
                    <xsl:call-template name="showRDAtag264helper">
                        <xsl:with-param name="field" select="."/>
                        <xsl:with-param name="url" select="$show_url"/>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="showRDAtag264helper">
        <xsl:param name="field"/>
        <xsl:param name="url"/>
        <xsl:variable name="ind2" select="$field/@ind2"/>
        <span>
	    <xsl:attribute name="class"><xsl:value-of select="concat('results_summary ', 'f264 ', 'ind2-',$ind2)"/></xsl:attribute>
            <xsl:choose>
                <xsl:when test="$ind2='0'">
                    <span class="label">Producer: </span>
                </xsl:when>
                <xsl:when test="$ind2='1'">
                    <span class="label">Publisher: </span>
                </xsl:when>
                <xsl:when test="$ind2='2'">
                    <span class="label">Distributor: </span>
                </xsl:when>
                <xsl:when test="$ind2='3'">
                    <span class="label">Manufacturer: </span>
                </xsl:when>
                <xsl:when test="$ind2='4'">
                    <span class="label">Copyright date: </span>
                </xsl:when>
            </xsl:choose>

            <xsl:if test="$field/marc:subfield[@code='a']">
                <xsl:call-template name="subfieldSelect">
                    <xsl:with-param name="codes">a</xsl:with-param>
                </xsl:call-template>
            </xsl:if>
            <xsl:text> </xsl:text>

            <xsl:choose>
                <xsl:when test="$url='1'">
                    <xsl:if test="$field/marc:subfield[@code='b']">
                         <a href="/cgi-bin/koha/catalogue/search.pl?q=Provider:{$field/marc:subfield[@code='b']}">
                         <xsl:call-template name="subfieldSelect">
                             <xsl:with-param name="codes">b</xsl:with-param>
                         </xsl:call-template>
                         </a>
                    </xsl:if>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if test="$field/marc:subfield[@code='b']">
                        <xsl:call-template name="subfieldSelect">
                            <xsl:with-param name="codes">b</xsl:with-param>
                        </xsl:call-template>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:text> </xsl:text>
            <xsl:call-template name="chopPunctuation">
                <xsl:with-param name="chopString">
                    <xsl:call-template name="subfieldSelect">
                        <xsl:with-param name="codes">c</xsl:with-param>
                    </xsl:call-template>
                </xsl:with-param>
            </xsl:call-template>

        </span>
    </xsl:template>

    <!-- https://stackoverflow.com/a/7523245 -->
    <xsl:template name="replace-string">
        <xsl:param name="text"/>
        <xsl:param name="replace"/>
        <xsl:param name="with"/>
        <xsl:choose>
            <xsl:when test="contains($text,$replace)">
                <xsl:value-of select="substring-before($text,$replace)"/>
                <xsl:value-of select="$with"/>
                <xsl:call-template name="replace-string">
                    <xsl:with-param name="text" select="substring-after($text,$replace)"/>
                    <xsl:with-param name="replace" select="$replace"/>
                    <xsl:with-param name="with" select="$with"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$text"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- koha-suomi: cover image -->
    <xsl:template name="cover-image-856u">
        <xsl:if test="marc:datafield[@tag=856]/marc:subfield[@code='u']">
          <xsl:for-each select="marc:datafield[@tag=856]">
            <xsl:variable name="SubqText">
              <xsl:value-of select="marc:subfield[@code='q']"/>
            </xsl:variable>
            <xsl:choose>
              <xsl:when test="substring($SubqText,1,5)='IMAGE' or substring($SubqText,1,5)='image' or $SubqText='img' or $SubqText='bmp' or $SubqText='cod' or $SubqText='gif' or $SubqText='ief' or $SubqText='jpe' or $SubqText='jpeg' or $SubqText='jpg' or $SubqText='jfif' or $SubqText='png' or $SubqText='svg' or $SubqText='tif' or $SubqText='tiff' or $SubqText='ras' or $SubqText='cmx' or $SubqText='ico' or $SubqText='pnm' or $SubqText='pbm' or $SubqText='pgm' or $SubqText='ppm' or $SubqText='rgb' or $SubqText='xbm' or $SubqText='xpm' or $SubqText='xwd'">
                <a class="cover_image_container">
                  <xsl:attribute name="href">
                    <xsl:value-of select="marc:subfield[@code='u']"/>
                  </xsl:attribute>
                    <xsl:element name="img">
                      <xsl:attribute name="src">
                        <xsl:value-of select="marc:subfield[@code='u']"/>
                      </xsl:attribute>
                      <xsl:attribute name="alt">
			<xsl:choose>
			  <xsl:when test="marc:subfield[@code='y']"><xsl:value-of select="marc:subfield[@code='y']"/></xsl:when>
			  <xsl:otherwise><xsl:value-of select="marc:subfield[@code='z']"/></xsl:otherwise>
			  </xsl:choose>
                      </xsl:attribute>
                    </xsl:element>
                </a>
              </xsl:when>
            </xsl:choose>
          </xsl:for-each>
        </xsl:if>
    </xsl:template>
    <!-- /koha-suomi: cover image -->

    <!-- koha-suomi: language -->
    <xsl:template name="show-lang-041">
       <xsl:if test="marc:datafield[@tag=041]">
          <xsl:for-each select="marc:datafield[@tag=041]">
             <span class="results_summary languages">
               <xsl:call-template name="show-lang-node">
		 <xsl:with-param name="langNode" select="marc:subfield[@code='a']"/>
		 <xsl:with-param name="langLabel">Language: </xsl:with-param>
	       </xsl:call-template>
               <xsl:call-template name="show-lang-node">
		 <xsl:with-param name="langNode" select="marc:subfield[@code='b']"/>
		 <xsl:with-param name="langLabel">Summary language: </xsl:with-param>
	       </xsl:call-template>
               <xsl:call-template name="show-lang-node">
		 <xsl:with-param name="langNode" select="marc:subfield[@code='d']"/>
		 <xsl:with-param name="langLabel">Spoken language: </xsl:with-param>
	       </xsl:call-template>
               <xsl:call-template name="show-lang-node">
		 <xsl:with-param name="langNode" select="marc:subfield[@code='h']"/>
		 <xsl:with-param name="langLabel">Original language: </xsl:with-param>
	       </xsl:call-template>
               <xsl:call-template name="show-lang-node">
		 <xsl:with-param name="langNode" select="marc:subfield[@code='j']"/>
		 <xsl:with-param name="langLabel">Subtitle language: </xsl:with-param>
	       </xsl:call-template>
             </span>
          </xsl:for-each>
       </xsl:if>
    </xsl:template>

    <xsl:template name="show-lang-node">
      <xsl:param name="langNode"/>
      <xsl:param name="langLabel"/>
      <xsl:if test="$langNode">
	<span class="language">
	  <span class="label"><xsl:value-of select="$langLabel"/></span>
          <xsl:for-each select="$langNode">
            <span>
	      <xsl:attribute name="class">lang_name-<xsl:value-of select="substring(translate(., ' .-;>&lt;|#', '_'),1,3)"/></xsl:attribute>
	      <xsl:call-template name="languageCodeText">
		<xsl:with-param name="code" select="substring(.,1,3)"/>
	      </xsl:call-template>
	    </span>
	  </xsl:for-each>
	</span>
      </xsl:if>
    </xsl:template>
    <!-- /koha-suomi: language -->

    <!-- koha-suomi: kielletty alle -->
    <xsl:template name="show-age-rating">
      <xsl:choose>
	<xsl:when test="marc:datafield[@tag=521]/marc:subfield[@code='a']">
	  <xsl:for-each select="marc:datafield[@tag=521]/marc:subfield[@code='a']">
	    <xsl:call-template name="show-age-rating-span">
              <xsl:with-param name="agelimit" select="."/>
	    </xsl:call-template>
	  </xsl:for-each>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:if test="marc:datafield[@tag=049]/marc:subfield[@code='c']">
	    <xsl:for-each select="marc:datafield[@tag=049]/marc:subfield[@code='c']">
	      <xsl:call-template name="show-age-rating-span">
		<xsl:with-param name="agelimit" select="."/>
	      </xsl:call-template>
	    </xsl:for-each>
	  </xsl:if>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:template>
    <xsl:template name="show-age-rating-span">
      <xsl:param name="agelimit"/>
      <xsl:variable name="tagelimit" select="translate($agelimit, ' .-;', '')"/>
      <xsl:if test="starts-with($tagelimit, 'K')">
        <span class="results_summary age_limit">Age restriction: <xsl:value-of select="$tagelimit"/>.</span>
      </xsl:if>
    </xsl:template>
    <!-- /koha-suomi: kielletty alle -->

    <!-- koha-suomi: lehden numero -->
    <!-- show 362a if it's not the same as end of 245a -->
    <xsl:template name="maybe-show-f362a">
      <xsl:if test="//marc:datafield[@tag=362]/marc:subfield[@code='a']">
	<xsl:variable name="f362ao" select="//marc:datafield[@tag=362]/marc:subfield[@code='a']"/>
	<xsl:variable name="f362a" select="translate($f362ao, ' .-;', '')"/>
	<xsl:variable name="f245a" select="translate(//marc:datafield[@tag=245]/marc:subfield[@code='a'], ' .-;', '')"/>
	<xsl:variable name="f362al" select="string-length($f362a)"/>
	<xsl:variable name="f245al" select="string-length($f245a)"/>
	<xsl:if test="not($f362a = substring($f245a, $f245al - $f362al + 1))">
	  <xsl:value-of select="$f362ao"/>
	  <xsl:text> </xsl:text>
	</xsl:if>
      </xsl:if>
    </xsl:template>
    <!-- /koha-suomi: lehden numero -->

    <!-- koha-suomi: ilmestymistiheys -->
    <xsl:template name="show-curr-pub-freq">
      <xsl:if test="//marc:datafield[@tag=310]/marc:subfield[@code='a']">
	<span class="results_summary curr_pub_freq">
	  <span class="label">Current publication frequency: </span>
	<xsl:value-of select="//marc:datafield[@tag=310]/marc:subfield[@code='a']"/>
	</span>
      </xsl:if>
    </xsl:template>
    <!-- /koha-suomi: ilmestymistiheys -->

    <xsl:template name="maybe-show-f347b">
      <xsl:if test="marc:datafield[@tag=347]/marc:subfield[@code='b']">
	<xsl:text> </xsl:text>
        <xsl:for-each select="marc:datafield[@tag=347]">
	  <xsl:call-template name="subfieldSelect">
            <xsl:with-param name="codes">b</xsl:with-param>
	  </xsl:call-template>
        </xsl:for-each>
      </xsl:if>
    </xsl:template>

</xsl:stylesheet>

<!-- Stylus Studio meta-information - (c)1998-2002 eXcelon Corp.
<metaInformation>
<scenarios/><MapperInfo srcSchemaPath="" srcSchemaRoot="" srcSchemaPathIsRelative="yes" srcSchemaInterpretAsXML="no" destSchemaPath="" destSchemaRoot="" destSchemaPathIsRelative="yes" destSchemaInterpretAsXML="no"/>
</metaInformation>
-->
