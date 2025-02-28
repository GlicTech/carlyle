@isTest
public class ConvertToPlainTextTest {
    
    @isTest
    static void stripHtmlTags() {
        
        List<string> richText = New List<String>{'<html><body>This is a text</body></html>'};
        List<string> plainText = New List<String>{'This is a text'};

        System.assertEquals(plainText, ConvertToPlainText.removeHtmlTags(richText));       
    }
}