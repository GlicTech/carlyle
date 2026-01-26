public class ConvertToPlainText{
    
    @InvocableMethod(Label='Convert to Plain Text' iconName='slds:standard:text_template')
    public static List<String> removeHtmlTags(List<String> richTextInput) {
        
        List<String> plainTextValue  = new List<String>(); 
        for (string s : richTextInput) {
            plainTextValue.add(s.stripHtmlTags());
        }
        return plainTextValue;
    }
}