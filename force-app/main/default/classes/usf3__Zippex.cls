/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class Zippex {
    global Zippex() {

    }
    global Zippex(Blob fileData) {

    }
    global void addFile(String fileName, Blob fileData, String crc32) {

    }
    global Boolean containsFile(String fileName) {
        return null;
    }
    global Blob getFile(String fileName) {
        return null;
    }
    global Map<String,String> getFileInfo(String fileName) {
        return null;
    }
    global Set<String> getFileNames() {
        return null;
    }
    global static Datetime getLastModDateTime(Integer lastModDate, Integer lastModtime) {
        return null;
    }
    global Blob getZipArchive() {
        return null;
    }
    global void removeFile(String fileName) {

    }
    global void removePrefix(String prefix) {

    }
    global void renameFile(String oldName, String newName) {

    }
    global static void unzipAttachment(Id srcAttId, Id destObjId, List<String> fileNames, Boolean attemptAsync) {

    }
global class FileObject {
    global Integer c_offsetToNextRecord;
    global String compressedFileData;
    global String compressedSize;
    global String compressionMethod;
    global String crc32;
    global String creatorVersion;
    global String diskNumStart;
    global String externalFileAtt;
    global String extraField;
    global String extraFieldLength;
    global String fileComment;
    global String fileCommentLength;
    global Boolean fileDataInZipStr;
    global String fileName;
    global String fileNameLength;
    global String gPFlagBit;
    global String internalFileAtt;
    global Integer l_offsetToNextRecord;
    global String lastModDate;
    global String lastModTime;
    global String minExtractorVersion;
    global String offsetOfLH;
    global String uncompressedSize;
    global FileObject() {

    }
    global FileObject(String zipFileString, Integer offset) {

    }
    global String assembleCentralFileHeader() {
        return null;
    }
    global String assembleLocalFileHeader() {
        return null;
    }
    global void readLocalFileHeader(String zipFileString, Integer offset) {

    }
}
}
