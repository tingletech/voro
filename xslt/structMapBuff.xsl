<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:mets="http://www.loc.gov/METS/"
  xmlns="http://www.loc.gov/METS/"
  xmlns:mix="http://www.loc.gov/mix/"
  xmlns:moa2="http://sunsite.berkeley.edu/MOA2/" 
  xmlns:cdl="http://www.cdlib.org/"
  version="1.0"
>
<!--	Buff out structMap from GenX to generate div labels -->

<xsl:include href="modsRightsInject.xsl"/>

<!-- set up some keys using @ID -->
<xsl:key name="file" match="mets:file" use="@ID"/>
<xsl:key name="md" match="mets:xmlData" use="../../@ID"/>

<xsl:template match="mets:mets">
<mets>
<xsl:for-each select="@*|namespace::*">
<!-- xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute -->
<xsl:copy/>
</xsl:for-each>
<xsl:if test="not(@PROFILE)">
<xsl:attribute name="PROFILE">http://sunsite.berkeley.edu/GenX</xsl:attribute>
</xsl:if>
<!-- xsl:attribute name="xmlns:cdl" value="http://www.cdlib.org/"/ -->
<xsl:choose>
  <xsl:when test="not(//metsHdr)">
	<xsl:apply-templates/>	
  </xsl:when>
  <xsl:otherwise>
	<metsHdr/>
	<xsl:apply-templates/>	
  </xsl:otherwise>
</xsl:choose>
</mets>
</xsl:template>

<xsl:template match="/">
   <xsl:apply-templates/>
</xsl:template>

<xsl:template match="mets:fptr">
<!-- xsl:if test="not(starts-with(key('file',@FILEID)/../@USE,'archive'))" -->
<mets:div>
   <xsl:attribute name="TYPE">
	<xsl:value-of select="key('file',@FILEID)/../@USE"/>
   </xsl:attribute>
   
<xsl:variable name="y">
	<xsl:call-template name="getY">
		<xsl:with-param name="IDREFS">
		<xsl:value-of select="key('file',@FILEID)/@ADMID"/>
		</xsl:with-param>
	</xsl:call-template>
</xsl:variable>

<xsl:variable name="x">
	<xsl:call-template name="getX">
		<xsl:with-param name="IDREFS">
		<xsl:value-of select="key('file',@FILEID)/@ADMID"/>
		</xsl:with-param>
	</xsl:call-template>
</xsl:variable>

<mets:fptr>
<xsl:for-each select="@*">
<xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
</xsl:for-each>
<!-- add in attributes for the height and width -->
<xsl:if test="$x">
   <!-- xsl:attribute name="cdl:X">
	<xsl:value-of select="$x"/>
   </xsl:attribute>
   <xsl:attribute name="cdl:Y">
	<xsl:value-of select="$y"/>
   </xsl:attribute -->
</xsl:if>
</mets:fptr>
</mets:div>
</xsl:template>

<!-- this template matches everything, leaving it marked up -->
<xsl:template match='*|@*'>
        <xsl:copy>
                <xsl:apply-templates select='@*|node()'/>
        </xsl:copy>
</xsl:template>

<xsl:template name="getY">
	<xsl:param name="IDREFS"/>
	<xsl:variable name="normalizedString">
    		<xsl:value-of 
		   select="concat(normalize-space($IDREFS), ' ')"/>
  	</xsl:variable>
	
<xsl:choose>
    <xsl:when test="$normalizedString!=' '">
      <xsl:variable name="firstOfString" 
	select="substring-before($normalizedString, ' ')"/>
      <xsl:variable name="restOfString" 
        select="substring-after($normalizedString, ' ')"/>

	<xsl:apply-templates
	 select="key('md',$firstOfString)/mix:mix/mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageLength" mode="label-y"/>

      <xsl:call-template name="getY">
        <xsl:with-param name="IDREFS" 
          select="$restOfString"/>
      </xsl:call-template>
    </xsl:when>
  </xsl:choose>
<!-- http://www.oreilly.com/catalog/xslt/chapter/ch05.html -->
</xsl:template>


<xsl:template name="getX">
	<xsl:param name="IDREFS"/>
	<xsl:variable name="normalizedString">
    		<xsl:value-of 
		   select="concat(normalize-space($IDREFS), ' ')"/>
  	</xsl:variable>
	
<xsl:choose>
    <xsl:when test="$normalizedString!=' '">
      <xsl:variable name="firstOfString" 
	select="substring-before($normalizedString, ' ')"/>
      <xsl:variable name="restOfString" 
        select="substring-after($normalizedString, ' ')"/>

	<xsl:apply-templates
	 select="key('md',$firstOfString)/mix:mix/mix:ImagingPerformanceAssessment/mix:SpatialMetrics/mix:ImageWidth" mode="label-x"/>

      <xsl:call-template name="getX">
        <xsl:with-param name="IDREFS" 
          select="$restOfString"/>
      </xsl:call-template>
    </xsl:when>
  </xsl:choose>
<!-- http://www.oreilly.com/catalog/xslt/chapter/ch05.html -->
</xsl:template>

<xsl:template name="getXY">
	<xsl:param name="IDREFS"/>
	<xsl:variable name="normalizedString">
    		<xsl:value-of 
		   select="concat(normalize-space($IDREFS), ' ')"/>
  	</xsl:variable>
	
<xsl:choose>
    <xsl:when test="$normalizedString!=' '">
      <xsl:variable name="firstOfString" 
	select="substring-before($normalizedString, ' ')"/>
      <xsl:variable name="restOfString" 
        select="substring-after($normalizedString, ' ')"/>

	<xsl:apply-templates
	 select="key('md',$firstOfString)/mix:mix/mix:ImagingPerformanceAssessment/mix:SpatialMetrics[mix:ImageWidth]" mode="label"/>

      <xsl:call-template name="getXY">
        <xsl:with-param name="IDREFS" 
          select="$restOfString"/>
      </xsl:call-template>
    </xsl:when>
  </xsl:choose>
<!-- http://www.oreilly.com/catalog/xslt/chapter/ch05.html -->
</xsl:template>

<xsl:template match="mix:SpatialMetrics" mode="label">
	<xsl:text> ( </xsl:text>
	<xsl:value-of select="mix:ImageWidth"/>
 	<xsl:text> x </xsl:text>
	<xsl:value-of select="mix:ImageLength"/>
 	<xsl:text> ) </xsl:text>
</xsl:template>

</xsl:stylesheet>
<!-- 
Brian Tingle
California Digital Library

Copyright (c) 2004 The Regents of the University of California
Permission is hereby granted, without written agreement and without
license or royalty fees, to use, copy, modify, and distribute this XSLT
style sheet for any purpose, provided that the above copyright notice
and the following two paragraphs appear in all copies of this
document.

IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
ARISING OUT OF THE USE OF THIS COMPUTER FILE, EVEN IF THE
UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGE.

THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE COMPUTER
FILE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE
UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.  
-->
