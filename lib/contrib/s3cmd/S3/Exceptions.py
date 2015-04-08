## Amazon S3 manager - Exceptions library
## Author: Michal Ludvig <michal@logix.cz>
##         http://www.logix.cz/michal
## License: GPL Version 2
## Copyright: TGRMN Software and contributors

from Utils import getTreeFromXml, unicodise, deunicodise
from logging import debug, info, warning, error
import ExitCodes

try:
    import xml.etree.ElementTree as ET
except ImportError:
    # xml.etree.ElementTree was only added in python 2.5
    import elementtree.ElementTree as ET

try:
    from xml.etree.ElementTree import ParseError as XmlParseError
except ImportError:
    # ParseError was only added in python2.7, before ET was raising ExpatError
    from xml.parsers.expat import ExpatError as XmlParseError

class S3Exception(Exception):
    def __init__(self, message = ""):
        self.message = unicodise(message)

    def __str__(self):
        ## Call unicode(self) instead of self.message because
        ## __unicode__() method could be overriden in subclasses!
        return deunicodise(unicode(self))

    def __unicode__(self):
        return self.message

    ## (Base)Exception.message has been deprecated in Python 2.6
    def _get_message(self):
        return self._message
    def _set_message(self, message):
        self._message = message
    message = property(_get_message, _set_message)


class S3Error (S3Exception):
    def __init__(self, response):
        self.status = response["status"]
        self.reason = response["reason"]
        self.info = {
            "Code" : "",
            "Message" : "",
            "Resource" : ""
        }
        debug("S3Error: %s (%s)" % (self.status, self.reason))
        if response.has_key("headers"):
            for header in response["headers"]:
                debug("HttpHeader: %s: %s" % (header, response["headers"][header]))
        if response.has_key("data") and response["data"]:
            try:
                tree = getTreeFromXml(response["data"])
            except XmlParseError:
                debug("Not an XML response")
            else:
                try:
                    self.info.update(self.parse_error_xml(tree))
                except Exception, e:
                    error("Error parsing xml: %s.  ErrorXML: %s" % (e, response["data"]))

        self.code = self.info["Code"]
        self.message = self.info["Message"]
        self.resource = self.info["Resource"]

    def __unicode__(self):
        retval = u"%d " % (self.status)
        retval += (u"(%s)" % (self.info.has_key("Code") and self.info["Code"] or self.reason))
        if self.info.has_key("Message"):
            retval += (u": %s" % self.info["Message"])
        return retval

    def get_error_code(self):
        if self.status in [301, 307]:
            return ExitCodes.EX_SERVERMOVED
        elif self.status in [400, 405, 411, 416, 501]:
            return ExitCodes.EX_SERVERERROR
        elif self.status == 403:
            return ExitCodes.EX_ACCESSDENIED
        elif self.status == 404:
            return ExitCodes.EX_NOTFOUND
        elif self.status == 409:
            return ExitCodes.EX_CONFLICT
        elif self.status == 412:
            return ExitCodes.EX_PRECONDITION
        elif self.status == 500:
            return ExitCodes.EX_SOFTWARE
        elif self.status == 503:
            return ExitCodes.EX_SERVICE
        else:
            return ExitCodes.EX_SOFTWARE

    @staticmethod
    def parse_error_xml(tree):
        info = {}
        error_node = tree
        if not error_node.tag == "Error":
            error_node = tree.find(".//Error")
        if error_node is not None:
            for child in error_node.getchildren():
                if child.text != "":
                    debug("ErrorXML: " + child.tag + ": " + repr(child.text))
                    info[child.tag] = child.text
        else:
            raise S3ResponseError("Malformed error XML returned from remote server.")
        return info


class CloudFrontError(S3Error):
    pass

class S3UploadError(S3Exception):
    pass

class S3DownloadError(S3Exception):
    pass

class S3RequestError(S3Exception):
    pass

class S3ResponseError(S3Exception):
    pass

class InvalidFileError(S3Exception):
    pass

class ParameterError(S3Exception):
    pass

# vim:et:ts=4:sts=4:ai
