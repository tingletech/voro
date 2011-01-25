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

<xsl:template match="/">
   <xsl:apply-templates/>
</xsl:template>

<xsl:template match="mets:div[mets:fptr]">
	<xsl:apply-templates/>
</xsl:template>

<!-- this template matches everything, leaving it marked up -->
<xsl:template match='*|@*'>
        <xsl:copy>
                <xsl:apply-templates select='@*|node()'/>
        </xsl:copy>
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
