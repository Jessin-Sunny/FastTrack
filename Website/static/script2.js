const dropzoneBox = document.getElementsByClassName("dropzone-box")[0];
const inputFiles = document.querySelectorAll(".dropzone-area input[type='file']");
const inputElement = inputFiles[0];

const dropZoneElement = inputElement.closest(".dropzone-area");
const fileLimit = 25000000; // 25MB in bytes

// Function to update the file list in the dropzone
const updateDropzoneFileList = (dropzoneElement, files) => {
  const dropzoneFileMessage = dropzoneElement.querySelector(".file-info");
  const filesString = Array.from(files).reduce((acc, file) => {
    return `${acc}<li>${file.name} (${file.size} bytes)</li>`;
  }, "");

  dropzoneFileMessage.innerHTML = `<ul>${filesString}</ul>`;
};

// Handle file input change event
inputElement.addEventListener("change", (e) => {
  const filesArr = Array.from(inputElement.files);
  const totalSize = filesArr.reduce((acc, file) => {
    return acc + file.size;
  }, 0);

  if (totalSize > fileLimit) {
    alert("Total file size is over 25MB!");
    return;
  }

  if (filesArr.length) {
    updateDropzoneFileList(dropZoneElement, filesArr);
  }
});

// Handle drag-over event
dropZoneElement.addEventListener("dragover", (e) => {
  e.preventDefault();
  dropZoneElement.classList.add("dropzone--over");
});

// Handle drag leave and drag end events
["dragleave", "dragend"].forEach((type) => {
  dropZoneElement.addEventListener(type, (e) => {
    dropZoneElement.classList.remove("dropzone--over");
  });
});

// Handle drop event
dropZoneElement.addEventListener("drop", (e) => {
  e.preventDefault();
  dropZoneElement.classList.remove("dropzone--over");

  const files = e.dataTransfer.files;
  const filesArr = Array.from(files);
  const totalSize = filesArr.reduce((acc, file) => {
    return acc + file.size;
  }, 0);

  if (totalSize > fileLimit) {
    alert("Total file size is over 25MB!");
    return;
  }

  if (filesArr.length) {
    inputElement.files = files; // Update the input files
    updateDropzoneFileList(dropZoneElement, filesArr);
  }
});

// Handle form reset event
dropzoneBox.addEventListener("reset", (e) => {
  const dropzoneFileMessage = dropZoneElement.querySelector(".file-info");
  dropzoneFileMessage.innerHTML = "<p>No Files Selected</p>";
});

// Handle form submit event
dropzoneBox.addEventListener("submit", (e) => {
  e.preventDefault();

  const myFile = document.getElementById("upload-file");
  const totalSize = Array.from(myFile.files).reduce((acc, file) => {
    return acc + file.size;
  }, 0);

  if (totalSize > fileLimit) {
    alert("Total file size is over 25MB!");
    return;
  }

  console.log("Files:", myFile.files);
  // Add your file upload logic here
});
// dropzoneBox.addEventListener("submit", (e) => {
//   e.preventDefault(); // Prevent default only if handling manually

//   const myFile = document.getElementById("upload-file");
//   if (myFile.files.length === 0) {
//       alert("Please select a file before saving.");
//       return;
//   }

//   dropzoneBox.submit(); // Manually submit the form
// });
document.querySelector(".dropzone-box").addEventListener("submit", function(e) {
  e.preventDefault();  // REMOVE this if form is not submitting
  this.submit();  // Manually submit
});



























/*const dropzoneBox = document.getElementsByClassName("dropzone-box")[0];
const inputFiles = document.querySelectorAll(".dropzone-area input[type='file']");
const inputElement = inputFiles[0];

const dropZoneElement = inputElement.closest(".dropzone-area");
const fileLimit = 25000000; // 25MB in bytes

// Function to update the file list in the dropzone
const updateDropzoneFileList = (dropzoneElement, files) => {
    const dropzoneFileMessage = dropzoneElement.querySelector(".file-info");
    const filesString = Array.from(files).reduce((acc, file) => {
        return `${acc}<li>${file.name} (${file.size} bytes)</li>`;
    }, "");

    dropzoneFileMessage.innerHTML = `<ul>${filesString}</ul>`;
};

// Handle file input change event
inputElement.addEventListener("change", (e) => {
    const filesArr = Array.from(inputElement.files);
    const totalSize = filesArr.reduce((acc, file) => {
        return acc + file.size;
    }, 0);

    if (totalSize > fileLimit) {
        alert("Total file size is over 25MB!");
        return;
    }

    if (filesArr.length) {
        updateDropzoneFileList(dropZoneElement, filesArr);
    }
});

// Handle drag-over event
dropZoneElement.addEventListener("dragover", (e) => {
    e.preventDefault();
    dropZoneElement.classList.add("dropzone--over");
});

// Handle drag leave and drag end events
["dragleave", "dragend"].forEach((type) => {
    dropZoneElement.addEventListener(type, (e) => {
        dropZoneElement.classList.remove("dropzone--over");
    });
});

// Handle drop event
dropZoneElement.addEventListener("drop", (e) => {
    e.preventDefault();
    dropZoneElement.classList.remove("dropzone--over");

    const files = e.dataTransfer.files;
    const filesArr = Array.from(files);
    const totalSize = filesArr.reduce((acc, file) => {
        return acc + file.size;
    }, 0);

    if (totalSize > fileLimit) {
        alert("Total file size is over 25MB!");
        return;
    }

    if (filesArr.length) {
        inputElement.files = files; // Update the input files
        updateDropzoneFileList(dropZoneElement, filesArr);
    }
});

// Handle form reset event
dropzoneBox.addEventListener("reset", (e) => {
    const dropzoneFileMessage = dropZoneElement.querySelector(".file-info");
    dropzoneFileMessage.innerHTML = "<p>No Files Selected</p>";
});

// Handle form submit event
dropzoneBox.addEventListener("submit", (e) => {
    e.preventDefault();

    const myFile = document.getElementById("upload-file");
    const totalSize = Array.from(myFile.files).reduce((acc, file) => {
        return acc + file.size;
    }, 0);

    if (totalSize > fileLimit) {
        alert("Total file size is over 25MB!");
        return;
    }

    console.log("Files:", myFile.files);
    // Add your file upload logic here
});

/*const dropzonebox = document.
getElementsByClassName ("dropzone-box")[0];
const inputFiles = document.querySelectorAll
{
    ".dropzone-area input[type='file')"
}
const inputElement = inputFiles[0];

const dropZoneElement = inputElement.closest (".dropzone-area");
const fileLimit = 25000000;

inputElement.addEventListener("change", (e)
=> {
    const filesArr = Array.from(inputElement.files);
    const totalSize filesArr.reduce((acc,file) => {
        acc += file.size;
        return acc;
    }, 0);


    if(totalSize > fileLimit) {
        alert("File is over 25MB!");
        return
    }

    if (filesArr.length) {
        updateDropzoneFileList(dropZoneElement.inputElement.files, filesArr);
    }
});

dropZoneElement.addEventListener

("dragover", (e) => {
    e.preventDefault();
    dropZonellement.classtist.add("dropzone--over");
});

["dragleave", "dragend"].forEach((type) => {
    dropZoneElement.addEventListener (type,(e) => {
        dropZoneElement.classList.remove("dropzone-over");
    });
});

dropZonellement.addEventListener("drop", (e)

e.preventDefault();

const filese dataTransfer.files;

const filesArr Array.fron(files);

const totalSize filesArr.reduce lacc, file) ( acc file.size;

return acc:

),0);

if (totalsize filelimit) (

alert("File is over 25MB1"); dropZoneElement.classList.remove ("dropzene--over");

return

if (files.length) (

InputElement. files files; updateDropzoneFileList(dropZoneElement, files, filesArr);

dropZonellement.classList.remove("dropzone--over");

const updatedropzoneFilelist (

dropzoneElement, files, filesArr

11

let dropzonefileMessage dropzoneElement querySelector( ".file-info"

const filesString filesArr, reducel

(acc, file)(

acc acc <11>5(file.name), $(file.size) bytes/111

return acc

dropzonefileMessage.innerHTML<ul>

5(filesString)

</ul

dropzoneBox.addEventListener("reset", (e)

Int dropzoneFileMessage dropZoneElement

querySelector

Tile-info"

dropzonefileflessage innerHTHE Les

Selected

11:

dropzonellax.addEventListener("submit", (e) const myfile document.getElementById

e.preventDefault():

("uptued-file");

const totalsize Array, fromtmyfile.files.reduce

(acc, file)

acc file size:

return acc

(totalsize filelimit alert("Files are over 25MB);

console.log("Files:", myFile, files):
*/