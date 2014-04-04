<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="xml" indent="yes"/>

    <xsl:template match="/xmlResponse">
        <xsl:copy>
            <xsl:apply-templates select="Person"/>
            <xsl:apply-templates select="document('2.xml')/*/Person"/>
            <xsl:apply-templates select="document('3.xml')/*/Person"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
