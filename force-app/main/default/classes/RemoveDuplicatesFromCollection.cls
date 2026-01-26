public class RemoveDuplicatesFromCollection {
    
    public class InputWrapper {
        @InvocableVariable(required=true)
        public List<String> inputStrings;
    }

    public class OutputWrapper {
        @InvocableVariable
        public List<String> uniqueStrings;
    }

    @InvocableMethod(label='Remove Duplicates from String Collection')
    public static List<OutputWrapper> removeDuplicates(List<InputWrapper> requests) {
        List<OutputWrapper> results = new List<OutputWrapper>();

        for (InputWrapper req : requests) {
            Set<String> uniqueSet = new Set<String>(req.inputStrings);
            OutputWrapper result = new OutputWrapper();
            result.uniqueStrings = new List<String>(uniqueSet);
            results.add(result);
        }

        return results;
    }
}