@isTest
public class RemoveDuplicatesFromCollectionTest {

    @isTest
    static void testRemoveDuplicates() {
        // Prepare the input list with duplicates
        List<String> testStrings = new List<String>{
            'Alpha', 'Beta', 'Gamma', 'Alpha', 'Beta'
        };

        // Wrap the input in the InputWrapper
        RemoveDuplicatesFromCollection.InputWrapper input = new RemoveDuplicatesFromCollection.InputWrapper();
        input.inputStrings = testStrings;

        // Put the wrapper into a list (Flow always sends a list)
        List<RemoveDuplicatesFromCollection.InputWrapper> inputs = new List<RemoveDuplicatesFromCollection.InputWrapper>{ input };

        // Call the method
        List<RemoveDuplicatesFromCollection.OutputWrapper> results = RemoveDuplicatesFromCollection.removeDuplicates(inputs);

        // There should only be one output wrapper
        System.assertEquals(1, results.size());

        // Grab the unique strings
        List<String> output = results[0].uniqueStrings;

        // There should be 3 unique values: Alpha, Beta, Gamma
        System.assertEquals(3, output.size());

        // Check the contents (order is not guaranteed)
        Set<String> expected = new Set<String>{ 'Alpha', 'Beta', 'Gamma' };
        for (String s : output) {
            System.assert(expected.contains(s), 'Unexpected string found: ' + s);
        }
    }
}